# AWS Configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
  default     = "kube-agro"
}

# Existing Infrastructure Configuration
variable "vpc_id" {
  description = "ID of the existing VPC to use"
  type        = string
}

variable "subnet_id" {
  description = "ID of the existing subnet to use"
  type        = string
}

variable "internet_gateway_id" {
  description = "ID of the existing internet gateway (optional, leave empty if VPC has default IGW)"
  type        = string
  default     = ""
}

# EC2 Configuration
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 20
}

# SSH Key Configuration
variable "public_key" {
  description = "Public key for SSH access to EC2 instance (optional)"
  type        = string
  default     = ""
}

# Optional: Custom AMI
variable "custom_ami_id" {
  description = "Custom AMI ID (optional, will use latest Amazon Linux 2 if not provided)"
  type        = string
  default     = ""
}

# Tags
variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
