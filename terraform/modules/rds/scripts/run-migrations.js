import * as fs from 'fs';
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';
import connect from '@databases/pg';
import pkg from '@databases/pg';
import { fromSSO } from '@aws-sdk/credential-providers';
const  {  sql, ConnectionPool } = pkg;

const awsProfile   = process.env.AWS_PROFILE;
const awsRegion    = process.env.AWS_REGION;
const host         = process.env.DB_HOST;
const port         = process.env.DB_PORT;
const dbname       = process.env.DB_DATABASE_NAME;
const rootUsername = process.env.DB_ROOT_USERNAME;
const dbSecretArn  = process.env.DB_SECRET_ARN;

/** API Client for Secrets Manager */
const credentials = await fromSSO({profile:awsProfile})
const secretsManager = new SecretsManagerClient({ region: awsRegion, credentials: credentials});

/** Get secret from Secrets Manager */
const getSecret = async (secretId) => {
  const cmd = new GetSecretValueCommand({ SecretId: secretId });
  const { SecretString } = await secretsManager.send(cmd);
  const secret = SecretString;
  return secret;
};

/** Run queries under the directory */
const runQueries = async (db, dir) => {
  /** SQL files under the directory */
  const files = fs.readdirSync(dir).filter(name => name.endsWith('.sql'));

  for await (let file of files) {
    const query = sql.file(`${dir}${file}`);
    try {
      console.info(`Run: ${file}`);
      const result = await db.query(query);
      if (result.length > 0) {
        console.info(result);
      }
    } catch (err) {
      console.error(err);
    }
  }
};

async function runMigrations(requestType = "Create") {

  const rootPassword = await getSecret(dbSecretArn);

  /** Database connection */
  const db = connect({
    host,
    port: Number(port),
    user: rootUsername,
    password: rootPassword,
    database: dbname || 'postgres',
    ssl: 'disable',
  });
  console.info('Connected to PostgreSQL database');

  switch (requestType) {
    case 'Create': {
      await runQueries(db, '../../../../src/supabase-db/sql/init-for-rds/');
      await runQueries(db, '../../../../src/supabase-db/sql/init-scripts/');
      await runQueries(db, '../../../../src/supabase-db/sql/migrations/');
      break;
    }
    case 'Update': {
      await runQueries(db, '../../../../src/supabase-db/sql/init-for-rds/');
      await runQueries(db, '../../../../src/supabase-db/sql/init-scripts/');
      await runQueries(db, '../../../../src/supabase-db/sql/migrations/');
      break;
    }
    case 'Delete': {
      break;
    }
  };

  await db.dispose();
  return {};
};

runMigrations();
