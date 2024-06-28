variable "aws_primary_profile" {
  type = string
  default = "<profile_name>"
}

variable "aws_secondary_profile" {
  type = string
  default = "<profile_name>"
}

variable "master_username" {
  type = string
  default = "supabase_admin"
}

variable "db_name" {
  type = string
  default = "postgres"
}

variable "encrypt_storage" {
  type = bool
  default = true
}

variable "skip_final_snapshot" {
  type = bool
  default = true
}

variable "primary_region" {
  type = string
  default = "us-east-1"
}

variable "secondary_region" {
  type = string
  default = "us-west-1"
}
