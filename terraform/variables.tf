variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "cardano-rwa"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

# EKS Configuration
variable "eks_instance_types" {
  description = "EC2 instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_desired_nodes" {
  description = "Desired number of EKS nodes"
  type        = number
  default     = 3
}

variable "eks_min_nodes" {
  description = "Minimum number of EKS nodes"
  type        = number
  default     = 1
}

variable "eks_max_nodes" {
  description = "Maximum number of EKS nodes"
  type        = number
  default     = 10
}

# RDS Configuration
variable "rds_allocated_storage" {
  description = "Allocated storage for RDS (GB)"
  type        = number
  default     = 20
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_username" {
  description = "RDS master username"
  type        = string
  default     = "postgres"
  sensitive   = true
}

variable "rds_backup_retention_days" {
  description = "RDS backup retention period (days)"
  type        = number
  default     = 7
}

# Environment-specific defaults
locals {
  environment_configs = {
    dev = {
      eks_instance_types = ["t3.micro"]
      eks_desired_nodes  = 1
      eks_min_nodes      = 1
      eks_max_nodes      = 3
      rds_instance_class = "db.t3.micro"
      rds_allocated_storage = 20
      rds_backup_retention_days = 7
    }
    staging = {
      eks_instance_types = ["t3.small"]
      eks_desired_nodes  = 2
      eks_min_nodes      = 1
      eks_max_nodes      = 5
      rds_instance_class = "db.t3.small"
      rds_allocated_storage = 100
      rds_backup_retention_days = 14
    }
    prod = {
      eks_instance_types = ["t3.medium"]
      eks_desired_nodes  = 3
      eks_min_nodes      = 3
      eks_max_nodes      = 10
      rds_instance_class = "db.r6i.large"
      rds_allocated_storage = 500
      rds_backup_retention_days = 30
    }
  }
}
