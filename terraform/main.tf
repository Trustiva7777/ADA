terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "cardano-rwa-tf-state"
    key            = "env/${var.environment}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "cardano-rwa-tf-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "cardano-rwa"
      ManagedBy   = "Terraform"
      CreatedAt   = timestamp()
    }
  }
}

# VPC & Networking
module "vpc" {
  source = "./modules/vpc"

  environment        = var.environment
  vpc_cidr          = var.vpc_cidr
  availability_zones = data.aws_availability_zones.available.names
  public_subnets    = var.public_subnet_cidrs
  private_subnets   = var.private_subnet_cidrs
}

# EKS Cluster
module "eks" {
  source = "./modules/eks"

  environment           = var.environment
  cluster_name          = "${var.project_name}-${var.environment}"
  kubernetes_version    = "1.29"
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  
  # Node groups
  node_groups = {
    primary = {
      instance_types = var.eks_instance_types
      desired_size   = var.eks_desired_nodes
      min_size       = var.eks_min_nodes
      max_size       = var.eks_max_nodes
    }
  }

  # Autoscaling
  enable_cluster_autoscaler = true
  
  depends_on = [module.vpc]
}

# RDS PostgreSQL
module "rds" {
  source = "./modules/rds"

  environment         = var.environment
  instance_identifier = "${var.project_name}-postgres-${var.environment}"
  allocated_storage   = var.rds_allocated_storage
  instance_class      = var.rds_instance_class
  engine_version      = "16"
  
  database_name = "cardano_rwa"
  username      = var.rds_username
  # password should be from AWS Secrets Manager in production
  
  vpc_id             = module.vpc.vpc_id
  subnet_group_name  = "${var.project_name}-db-subnet"
  private_subnet_ids = module.vpc.private_subnet_ids
  
  # Backups & recovery
  backup_retention_period = var.rds_backup_retention_days
  multi_az                = var.environment == "prod" ? true : false
  storage_encrypted       = true
  
  # Security
  publicly_accessible = false
  
  depends_on = [module.vpc]
}

# Security Groups
resource "aws_security_group" "cluster_security_group" {
  name_prefix = "${var.project_name}-cluster-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-cluster-sg"
  }
}

# Outputs
output "eks_cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS cluster endpoint"
}

output "eks_cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS cluster name"
}

output "rds_endpoint" {
  value       = module.rds.db_instance_endpoint
  description = "RDS PostgreSQL endpoint"
  sensitive   = true
}

output "rds_database_name" {
  value = module.rds.database_name
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}
