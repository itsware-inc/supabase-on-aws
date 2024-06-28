# AWS-ALB-ECS
Templates for ECS(fargate) and ALB pattern

To use this project, Ensure you have the following:
  1. Your own AWS account, with access keys for a deployment role.
  2. Docker installed on your machine.
  3. Terraform installed on your machine
  4. AWS CLI Installed

Steps to use:
  1. Clone the repo to your desired location
  2. Edit the terraform.tfvars file with your desired values
  3. Run "terraform init", "terraform plan" and "terraform apply"
  4. To access the application, navigate to the Load Balancer in the
     AWS console and paste the dns name of the Load Balancer in a new tab. 
