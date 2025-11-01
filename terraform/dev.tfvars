environment = "dev"
aws_region  = "us-east-1"

# Use dev-specific values from locals
eks_instance_types       = ["t3.micro"]
eks_desired_nodes        = 1
eks_min_nodes            = 1
eks_max_nodes            = 3

rds_instance_class      = "db.t3.micro"
rds_allocated_storage   = 20
rds_backup_retention_days = 7

vpc_cidr           = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
