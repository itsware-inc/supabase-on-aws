variable "region" {
  description = "Main region for all resources"
  type        = string
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the main VPC"
}

variable "public_subnet_1" {
  type        = string
  description = "CIDR block for public subnet 1"
}

variable "public_subnet_2" {
  type        = string
  description = "CIDR block for public subnet 2"
}

variable "private_subnet_1" {
  type        = string
  description = "CIDR block for private subnet 1"
}

variable "private_subnet_2" {
  type        = string
  description = "CIDR block for private subnet 2"
}

variable "availibilty_zone_1" {
  type        = string
  description = "First availibility zone"
}

variable "availibilty_zone_2" {
  type        = string
  description = "First availibility zone"
}
  
variable "default_tags" {
  type = map
  default = {
    Application = "Demo App"
    Environment = "Dev"
  }
}

variable "container_port" {
  description = "Port that needs to be exposed for the application"
}

variable "shared_config_files" {
  description = "Path of your shared config file in .aws folder"
}
  
variable "shared_credentials_files" {
  description = "Path of your shared credentials file in .aws folder"
}

variable "credential_profile" {
  description = "Profile name in your credentials file"
  type        = string
}

variable "auth_service_name" {
  description = "Auth service name"
  type = string
  default = "auth-service"
}

variable "auth_service_instance_count" {
  description = "Auth service instance count"
  type = string
  default = "1"
}
 
variable "auth_image_url" {
  description = "Auth image (gotrue) url"
  type = string
  default = "public.ecr.aws/supabase/gotrue"
}

variable "auth_image_tag" {
  description = "Auth image tag (version)"
  type = string
  default = "v2.154.0"
}

variable "auth_service_container_port" {
  description = "Auth service port"
  type = number
  default = 9999
}

variable "rest_service_name" {
  description = "Rest service name"
  type = string
  default = "rest-service"
}

variable "rest_service_instance_count" {
  description = "Rest service instance count"
  type = string
  default = "1"
}
 
variable "rest_image_url" {
  description = "Rest image (postgrest) url"
  type = string
  default = "public.ecr.aws/supabase/postgrest"
}

variable "rest_image_tag" {
  description = "Rest image tag (version)"
  type = string
  default = "v11.2.0"
}

variable "rest_service_container_port" {
  description = "Rest service port"
  type = number
  default = 3000
}


variable "realtime_service_name" {
  description = "Realtime service name"
  type = string
  default = "realtime-service"
}

variable "realtime_service_instance_count" {
  description = "Realtime service instance count"
  type = string
  default = "1"
}
 
variable "realtime_image_url" {
  description = "Realtime image url"
  type = string
  default = "public.ecr.aws/supabase/realtime"
}

variable "realtime_image_tag" {
  description = "Realtime image tag (version)"
  type = string
  default = "v2.25.27"
}

variable "realtime_service_container_port" {
  description = "Realtime service port"
  type = number
  default = 4000
}

variable "storage_service_name" {
  description = "Storage service name"
  type = string
  default = "storage-service"
}

variable "storage_service_instance_count" {
  description = "Storage service instance count"
  type = string
  default = "1"
}
 
variable "storage_image_url" {
  description = "Storage image (storage-api) url"
  type = string
  default = "public.ecr.aws/supabase/storage-api"
}

variable "storage_image_tag" {
  description = "Storage image tag (version)"
  type = string
  default = "v0.43.11"
}

variable "storage_service_container_port" {
  description = "Storage service port"
  type = number
  default = 5000
}

variable "imgproxy_service_name" {
  description = "IMGProxy service name"
  type = string
  default = "imgproxy-service"
}

variable "imgproxy_service_instance_count" {
  description = "IMGProxy service instance count"
  type = string
  default = "1"
}
 
variable "imgproxy_image_url" {
  description = "IMGProxy image url"
  type = string
  default = "public.ecr.aws/supabase/imgproxy"
}

variable "imgproxy_image_tag" {
  description = "IMGProxy image tag (version)"
  type = string
  default = "v1.2.0"
}

variable "imgproxy_service_container_port" {
  description = "IMGProxy service port"
  type = number
  default = 5001
}

variable "postgresmeta_service_name" {
  description = "Postgres metadata service name"
  type = string
  default = "postgresmeta-service"
}

variable "postgresmeta_service_instance_count" {
  description = "Postgres metadata service instance count"
  type = string
  default = "1"
}
 
variable "postgresmeta_image_url" {
  description = "Postgres metadata image url"
  type = string
  default = "public.ecr.aws/supabase/postgres-meta"
}

variable "postgresmeta_image_tag" {
  description = "Postgres metadata image tag (version)"
  type = string
  default = "v0.74.2"
}

variable "postgresmeta_service_container_port" {
  description = "Postgres metadata service port"
  type = number
  default = 8080
}

variable "kong_service_name" {
  description = "Kong service name"
  type = string
  default = "kong-service"
}

variable "kong_service_instance_count" {
  description = "Kong service instance count"
  type = string
  default = "1"
}
 
variable "kong_image_url" {
  description = "Kong image url"
  type = string
  default = "public.ecr.aws/u3p7q2r8/kong"
}

variable "kong_image_tag" {
  description = "Kong image tag (version)"
  type = string
  default = "latest"
}

variable "kong_service_container_port" {
  description = "Kong service port"
  type = number
  default = 8000
}


variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type = string
  default = "supabase-ecs-cluster"
}
