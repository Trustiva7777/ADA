environment = "prod"
aws_region  = "us-east-1"

# Use prod-specific values - high availability
eks_instance_types       = ["t3.medium"]
eks_desired_nodes        = 3
eks_min_nodes            = 3
eks_max_nodes            = 10

rds_instance_class      = "db.r6i.large"
rds_allocated_storage   = 500
rds_backup_retention_days = 30

vpc_cidr           = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
