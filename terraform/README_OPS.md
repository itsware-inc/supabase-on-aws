The purpose of this README is to provide the thought process being this collection of terraform modules 
which are meant to be used to stand up a supabase environment's backend (studio is not included)

The original plan was to deploy supabase via terraform in the following order , which is meant
to mimic what I believed were the dependencies between tiers of the supabase architecture:

* VPC
* RDS
* Bastion
* ECS Services
  * Kong
  * Auth
  * Image
  * Storage
  * Meta
  * REST
* ECS Service Security Groups
* CloudFront


The way that the terraform modules are currently configured has an expectation that the cloud ops engineer
will cd into each module directory and perform the terraform init, plan (optional) and apply commands.

The intent for VPC was to create the supabase VPC and public private subnets.

Starting there , we end up with the VPC and private subnets that will be needed by RDS and Bastion

Next, we move to RDS . It would be deployed so that once its deploy process is finished , we will have
the Global database deployed with the primary in us-east-1 and the read replica in us-west-1.

*NOTE* : The RDS terraform module directory includes a scripts directory which is used to run the migration scripts
meant for the RDS through the Bastion once it is set up. A node environment needs to be initialized in addition to
the correct packages being installed for the aws sdk.

*NOTE* : The environment variables that I export so that I can run the migration script (and other aws commands) are:
```
export CLUSTER_IDENTIFIER=supabase-primary-cluster
export AWS_PROFILE=<aws_profile>
export AWS_REGION=<aws_region>
export DB_PORT=<db_port>
export DB_ROOT_USERNAME=supabase_admin
export DB_DATABASE_NAME=postgres
export DB_SECRET_ARN=<supabase_db_password_secret_arn>
export DB_HOST=127.0.0.1
```

Next, we move to the Bastion. The reason I went for a secure bastion is so that we could use it to 
run the migration scripts that are housed in the supabase Supabase-DB folder using the run-migrations.js script
in the RDS terraform directory (the scripts subfolder) once it has been deployed. 

*NOTE* : The Bastion needs to be
deployed into the same region as the RDS primary, so that we are able to attach and additional ENI to it and then 
use an ssh port forward to redirect psql commands from 127.0.0.1 to the RDS primary instance through the Bastion instance.

*NOTE*: An ENI needs to be created in the subnet where the RDS primary was deployed via the console (or terraform, if you prefer)

*NOTE* : This is the command I ran to attach the ENI once the Bastion is ready 
```
aws ec2 attach-network-interface --device-index 1 --instance-id $AWS_INSTANCE_ID --network-interface-id $ENI_INTERFACE_ID
```

Here is the original repo for the Bastion which will help to add context to how it should be used : https://github.com/aws-samples/secured-bastion-host-terraform

I am currently able to deploy the VPC, RDS and Bastion and then begin to run the migration scripts.

I can deploy the ECS services, but the terraform is a blob right now and a bit messy. I intend to break each service out into its own .tf file.
