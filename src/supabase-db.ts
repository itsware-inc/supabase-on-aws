import * as cdk from 'aws-cdk-lib';
import * as appmesh from 'aws-cdk-lib/aws-appmesh';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as events from 'aws-cdk-lib/aws-events';
import * as targets from 'aws-cdk-lib/aws-events-targets';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import { NodejsFunction } from 'aws-cdk-lib/aws-lambda-nodejs';
import * as rds from 'aws-cdk-lib/aws-rds';
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager';
import * as ssm from 'aws-cdk-lib/aws-ssm';
import * as cr from 'aws-cdk-lib/custom-resources';
import { Construct } from 'constructs';

// Support for Aurora Serverless v2
enum ServerlessInstanceType { SERVERLESS = 'serverless' }
type CustomInstanceType = ServerlessInstanceType | ec2.InstanceType;
const CustomInstanceType = { ...ServerlessInstanceType, ...ec2.InstanceType };

const excludeCharacters = '%+~`#$&*()|[]{}:;<>?!\'/@\"\\='; // for Password

interface SupabaseDatabaseProps {
  vpc: ec2.IVpc;
  mesh?: appmesh.IMesh;
}

export class SupabaseDatabase extends rds.DatabaseCluster {
  multiAzParameter: cdk.CfnParameter;
  virtualService?: appmesh.VirtualService;
  virtualNode?: appmesh.VirtualNode;
  url: ssm.StringParameter;
  urlAuth: ssm.StringParameter;

  constructor(scope: Construct, id: string, props: SupabaseDatabaseProps) {

    const { vpc, mesh } = props;

    const engine = rds.DatabaseClusterEngine.auroraPostgres({
      version: rds.AuroraPostgresEngineVersion.of('14.3', '14'),
    });

    const parameterGroup = new rds.ParameterGroup(scope, 'ParameterGroup', {
      engine,
      description: `Supabase parameter group for aurora-postgresql ${engine.engineVersion?.majorVersion}`,
      parameters: {
        'shared_preload_libraries': 'pg_stat_statements, pgaudit, pg_cron',
        // Logical Replication - https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/AuroraPostgreSQL.Replication.Logical.html
        'rds.logical_replication': '1',
        'max_replication_slots': '20', // Default Aurora:20, Supabase:5
        'max_wal_senders': '20', // Default Aurora:20, Supabase:10
        'max_logical_replication_workers': '4',
        'autovacuum_max_workers': 'GREATEST({DBInstanceClassMemory/64371566592},2)', // Default: GREATEST({DBInstanceClassMemory/64371566592},3)
        'max_parallel_workers': '2', // Default: GREATEST(${DBInstanceVCPU/2},8)
        //'max_worker_processes': '', // Default: GREATEST(${DBInstanceVCPU*2},8)

        'max_slot_wal_keep_size': '1024', // https://github.com/supabase/realtime
      },
    });

    super(scope, id, {
      engine,
      parameterGroup,
      storageEncrypted: true,
      instances: 2,
      instanceProps: {
        instanceType: CustomInstanceType.SERVERLESS as unknown as ec2.InstanceType,
        enablePerformanceInsights: true,
        vpc,
      },
      credentials: rds.Credentials.fromGeneratedSecret('supabase_admin', { excludeCharacters }),
      defaultDatabaseName: 'postgres',
    });

    this.multiAzParameter = new cdk.CfnParameter(this, 'MultiAz', {
      description: 'Create a replica at another AZ',
      type: 'String',
      default: 'false',
      allowedValues: ['true', 'false'],
    });
    const isMultiAz = new cdk.CfnCondition(this, 'MultiAzCondition', { expression: cdk.Fn.conditionEquals(this.multiAzParameter, 'true') });
    (this.node.findChild('Instance2') as rds.CfnDBInstance).addOverride('Condition', isMultiAz.logicalId);

    // Support for Aurora Serverless v2 ---------------------------------------------------
    const serverlessV2ScalingConfiguration = {
      MinCapacity: 0.5,
      MaxCapacity: 32,
    };
    const dbScalingConfigure = new cr.AwsCustomResource(this, 'DbScalingConfigure', {
      resourceType: 'Custom::AuroraServerlessV2ScalingConfiguration',
      onCreate: {
        service: 'RDS',
        action: 'modifyDBCluster',
        parameters: {
          DBClusterIdentifier: this.clusterIdentifier,
          ServerlessV2ScalingConfiguration: serverlessV2ScalingConfiguration,
        },
        physicalResourceId: cr.PhysicalResourceId.of(this.clusterIdentifier),
      },
      onUpdate: {
        service: 'RDS',
        action: 'modifyDBCluster',
        parameters: {
          DBClusterIdentifier: this.clusterIdentifier,
          ServerlessV2ScalingConfiguration: serverlessV2ScalingConfiguration,
        },
        physicalResourceId: cr.PhysicalResourceId.of(this.clusterIdentifier),
      },
      policy: cr.AwsCustomResourcePolicy.fromSdkCalls({
        resources: cr.AwsCustomResourcePolicy.ANY_RESOURCE,
      }),
    });
    this.node.children.filter(child => child.node.id.startsWith('Instance')).map(child => {
      child.node.addDependency(dbScalingConfigure);
    });
    // Support for Aurora Serverless v2 ---------------------------------------------------

    // Sync to SSM Parameter Store for database_url ---------------------------------------
    const databaseUrl = `postgres://${this.secret?.secretValueFromJson('username').toString()}:${this.secret?.secretValueFromJson('password').toString()}@${this.secret?.secretValueFromJson('host').toString()}:${this.secret?.secretValueFromJson('port').toString()}/${this.secret?.secretValueFromJson('dbname').toString()}`;
    this.url = new ssm.StringParameter(this, 'UrlParameter', {
      parameterName: `/${cdk.Aws.STACK_NAME}/Database/Url`,
      description: 'The standard connection PostgreSQL URI format.',
      stringValue: databaseUrl,
      simpleName: false,
    });

    this.urlAuth = new ssm.StringParameter(this, 'authUrlParameter', {
      parameterName: `/${cdk.Aws.STACK_NAME}/Database/Url/search_path/auth`,
      description: 'The standard connection PostgreSQL URI format with "?search_path=auth".',
      stringValue: `${databaseUrl}?search_path=auth`,
      simpleName: false,
    });

    const syncSecretFunction = new NodejsFunction(this, 'ForceDeployFunction', {
      description: 'Supabase - Sync DB secret to parameter store',
      entry: 'src/functions/db-secret-sync.ts',
      runtime: lambda.Runtime.NODEJS_16_X,
      architecture: lambda.Architecture.ARM_64,
      environment: {
        URL_PARAMETER_NAME: this.url.parameterName,
      },
    });
    this.url.grantWrite(syncSecretFunction);
    this.urlAuth.grantWrite(syncSecretFunction);
    this.secret?.grantRead(syncSecretFunction);

    new events.Rule(this, 'SecretChangeRule', {
      description: 'Supabase - Update parameter store, when DB secret rotated',
      eventPattern: {
        source: ['aws.secretsmanager'],
        detail: {
          eventName: ['RotationSucceeded'],
          additionalEventData: {
            SecretId: [this.secret?.secretArn],
          },
        },
      },
      targets: [new targets.LambdaFunction(syncSecretFunction)],
    });
    // Sync to SSM Parameter Store for database_url ---------------------------------------

    const rotationSecurityGroup = new ec2.SecurityGroup(this, 'RotationSecurityGroup', { vpc });
    this.secret?.addRotationSchedule('Rotation', {
      automaticallyAfter: cdk.Duration.days(30),
      hostedRotation: secretsmanager.HostedRotation.postgreSqlSingleUser({
        functionName: 'SupabaseDatabaseSecretRotationFunction',
        excludeCharacters,
        securityGroups: [rotationSecurityGroup],
        vpc,
      }),
    });
    this.connections.allowDefaultPortFrom(rotationSecurityGroup, 'Lambda to rotate secrets');

    const initFunction = new NodejsFunction(this, 'InitFunction', {
      description: 'Supabase - Database init function',
      entry: './src/functions/db-init/index.ts',
      bundling: {
        nodeModules: [
          '@databases/pg',
        ],
        commandHooks: {
          beforeInstall: (_inputDir, _outputDir) => {
            return [];
          },
          beforeBundling: (_inputDir, _outputDir) => {
            return [];
          },
          afterBundling: (inputDir, outputDir) => {
            return [`cp ${inputDir}/src/functions/db-init/*.sql ${outputDir}`];
          },
        },
      },
      runtime: lambda.Runtime.NODEJS_16_X,
      timeout: cdk.Duration.seconds(60),
      vpc,
    });

    this.connections.allowDefaultPortFrom(initFunction);
    this.secret?.grantRead(initFunction);

    const initProvider = new cr.Provider(this, 'InitProvider', { onEventHandler: initFunction });

    const init = new cdk.CustomResource(this, 'Init', {
      serviceToken: initProvider.serviceToken,
      resourceType: 'Custom::SupabaseDatabaseInit',
      properties: {
        SecretId: this.secret?.secretArn,
        Hostname: this.clusterEndpoint.hostname,
      },
    });
    init.node.addDependency(this.node.findChild('Instance1'));

    if (typeof mesh != 'undefined') {
      this.virtualNode = new appmesh.VirtualNode(this, 'VirtualNode', {
        serviceDiscovery: appmesh.ServiceDiscovery.dns(this.clusterEndpoint.hostname, appmesh.DnsResponseType.ENDPOINTS),
        listeners: [appmesh.VirtualNodeListener.tcp({ port: this.clusterEndpoint.port })],
        mesh,
      });

      this.virtualService = new appmesh.VirtualService(this, 'VirtualService', {
        virtualServiceName: this.clusterEndpoint.hostname,
        virtualServiceProvider: appmesh.VirtualServiceProvider.virtualNode(this.virtualNode),
      });
    }

  }
}
