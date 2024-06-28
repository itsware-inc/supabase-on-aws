provider "aws" {
  region  = var.primary_region
  profile = var.aws_primary_profile
}

provider "aws" {
  alias = "secondary"
  region = var.secondary_region
  profile = var.aws_secondary_profile
}

data "aws_caller_identity" "current" {}

data "aws_db_subnet_group" "supabase_primary_vpc" {
  name = "supabase-primary-vpc"
}

data "aws_db_subnet_group" "supabase_secondary_vpc" {
  provider  = aws.secondary
  name = "supabase-secondary-vpc"
}

locals {
  name               = "supabase-global-rds" 
}

################################################################################
# Supporting Resources
################################################################################

resource "random_uuid" "session-id" {
}

data "aws_secretsmanager_random_password" "master_pw" {
  password_length     = 30
  exclude_numbers     = false
  exclude_punctuation = true
  include_space       = false
}

resource "aws_secretsmanager_secret" "supabase_db_password" {
  name = "supabase_db_password-${random_uuid.session-id.result}"
  tags = {
    Name = "supabase_db_password"
  }
}

resource "aws_secretsmanager_secret_version" "supabase_db_password" {
  secret_id = aws_secretsmanager_secret.supabase_db_password.id
  secret_string = data.aws_secretsmanager_random_password.master_pw.random_password
}


resource "aws_kms_key" "rds_cluster_kms_key" {
  multi_region = true
  tags = {
    Name = "rds_cluster_kms_key"
    multi_region = true
  }
}

resource "aws_kms_replica_key" "rds_cluster_kms_key_replica" {
  provider                = aws.secondary
  description             = "multi-region replica key"
  primary_key_arn         = aws_kms_key.rds_cluster_kms_key.arn
}


resource "aws_rds_cluster_parameter_group" "default" {
  name   = "rds-cluster-pg"    
  family = "aurora-postgresql15" 

  parameter {
    name = "rds.force_ssl"
    value = "0"
  }

  parameter {
    name  =  "shared_preload_libraries"
    value = "pg_tle, pg_stat_statements, pgaudit, pg_cron"
    apply_method = "pending-reboot"
  }

  parameter {
    name = "rds.logical_replication"
    value = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "max_slot_wal_keep_size"
    value = "1024" // https://github.com/supabase/realtime
  }

 }

resource "aws_rds_global_cluster" "supabase" {
  global_cluster_identifier = "global-supabase-cluster"
  engine            = "aurora-postgresql"
  engine_version    = "15.4"
  database_name     = var.db_name
  storage_encrypted = var.encrypt_storage
}

resource "aws_rds_cluster" "supabase-primary" {
  provider                        = aws
  engine                          = aws_rds_global_cluster.supabase.engine
  engine_version                  = aws_rds_global_cluster.supabase.engine_version
  engine_mode                     = "provisioned"
  cluster_identifier              = "supabase-primary-cluster"
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.default.id 
  apply_immediately               = true
  master_username                 = var.master_username
  master_password                 = data.aws_secretsmanager_random_password.master_pw.random_password
  database_name                   = aws_rds_global_cluster.supabase.database_name
  global_cluster_identifier       = aws_rds_global_cluster.supabase.id 
  skip_final_snapshot             = var.skip_final_snapshot
  storage_encrypted               = aws_rds_global_cluster.supabase.storage_encrypted
  kms_key_id                      = aws_kms_key.rds_cluster_kms_key.arn
  db_subnet_group_name            = data.aws_db_subnet_group.supabase_primary_vpc.name


  serverlessv2_scaling_configuration {
    min_capacity = 1
    max_capacity = 2
  }
}

resource "aws_rds_cluster_instance" "supabase-primary" {
  provider             = aws
  engine               = aws_rds_global_cluster.supabase.engine
  engine_version       = aws_rds_global_cluster.supabase.engine_version
  instance_class       = "db.serverless"
  identifier           = "supabase-primary-cluster-instance"
  cluster_identifier   = aws_rds_cluster.supabase-primary.id
  monitoring_interval  = 0
}

# https://github.com/hashicorp/terraform-provider-aws/issues/28339
resource "null_resource" "aws_rds_server_check" {
  triggers = {
    db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.default.id 
    master_password                 = data.aws_secretsmanager_random_password.master_pw.random_password
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/wait-for-db-cluster.sh"

    environment = {
      AWS_PROFILE        = var.aws_primary_profile
      AWS_REGION         = var.primary_region
      CLUSTER_IDENTIFIER = aws_rds_cluster.supabase-primary.cluster_identifier
    }
  }
}

resource "aws_rds_cluster" "supabase-secondary" {
  provider                  = aws.secondary
  engine                    = aws_rds_global_cluster.supabase.engine
  engine_version            = aws_rds_global_cluster.supabase.engine_version
  engine_mode               = "provisioned"
  cluster_identifier        = "supabase-secondary-cluster"
  global_cluster_identifier = aws_rds_global_cluster.supabase.id
  db_subnet_group_name      = data.aws_db_subnet_group.supabase_secondary_vpc.name
  skip_final_snapshot       = var.skip_final_snapshot
  storage_encrypted         = aws_rds_global_cluster.supabase.storage_encrypted
  kms_key_id                = aws_kms_replica_key.rds_cluster_kms_key_replica.arn
  source_region             = var.primary_region
  serverlessv2_scaling_configuration {
    min_capacity = 1
    max_capacity = 2
  }

  depends_on = [
    aws_rds_cluster_instance.supabase-primary
  ]
}

resource "aws_rds_cluster_instance" "supabase-secondary" {
  provider             = aws.secondary
  engine               = aws_rds_global_cluster.supabase.engine
  engine_version       = aws_rds_global_cluster.supabase.engine_version
  instance_class       = "db.serverless"
  identifier           = "supabase-secondary-cluster-instance"
  cluster_identifier   = aws_rds_cluster.supabase-secondary.id
}

data "aws_iam_policy_document" "rds" {
  statement {
    sid       = "Enable IAM User Permissions"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
        data.aws_caller_identity.current.arn,
      ]
    }
  }

  statement {
    sid = "Allow use of the key"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]

    principals {
      type = "Service"
      identifiers = [
        "monitoring.rds.amazonaws.com",
        "rds.amazonaws.com",
      ]
    }
  }
}

resource "aws_kms_key" "primary" {
  policy = data.aws_iam_policy_document.rds.json
}

resource "aws_kms_key" "secondary" {
  provider = aws.secondary

  policy = data.aws_iam_policy_document.rds.json
}
