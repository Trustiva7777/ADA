# Infrastructure-as-Code (IaC) Implementation Guide

## Overview

This guide covers infrastructure provisioning using Terraform for multi-environment deployments (dev, staging, production) on AWS, Azure, or GCP.

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    Git Repository                         │
│  ├── terraform/                                           │
│  │   ├── environments/                                    │
│  │   │   ├── dev/                     (terraform.tfvars)  │
│  │   │   ├── staging/                 (terraform.tfvars)  │
│  │   │   └── prod/                    (terraform.tfvars)  │
│  │   ├── modules/                                         │
│  │   │   ├── eks/                     (EKS cluster)       │
│  │   │   ├── rds/                     (Postgres DB)       │
│  │   │   ├── networking/              (VPC, Security)     │
│  │   │   ├── monitoring/              (Prometheus, etc)   │
│  │   │   └── security/                (IAM, Key Vault)    │
│  │   └── main.tf, variables.tf, outputs.tf               │
│  └── .github/workflows/                                   │
│      └── terraform-deploy.yml         (CI/CD)             │
└──────────────────────────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────┬─────────────────┐
        │                │                 │
        ▼                ▼                 ▼
    ┌────────┐      ┌────────┐       ┌────────┐
    │   Dev  │      │Staging │       │  Prod  │
    │Environment│  │Environment│  │Environment│
    └────────┘      └────────┘       └────────┘
```

## Part 1: Project Structure

```bash
terraform/
├── main.tf                    # Root configuration
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── terraform.tfstate          # State file (store in S3/Azure)
├── terraform.tfstate.backup   # State backup
│
├── environments/
│   ├── dev/
│   │   ├── terraform.tfvars
│   │   ├── backend.tf         # S3 backend config
│   │   └── vpc.tf             # Dev-specific overrides
│   ├── staging/
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   └── prod/
│       ├── terraform.tfvars
│       ├── backend.tf
│       └── vpc.tf             # Multi-AZ, high availability
│
├── modules/
│   ├── eks/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── rds/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── networking/
│   │   ├── main.tf            # VPC, subnets, NAT
│   │   ├── security_groups.tf
│   │   └── outputs.tf
│   ├── monitoring/
│   │   ├── main.tf
│   │   └── outputs.tf
│   └── security/
│       ├── main.tf            # IAM, KMS
│       └── outputs.tf
│
└── scripts/
    ├── init.sh                # Initialize Terraform
    ├── plan.sh                # Plan changes
    ├── apply.sh               # Apply changes
    └── destroy.sh             # Destroy resources
```

## Part 2: Core Terraform Configuration

### 2.1 Main Configuration (terraform/main.tf)

```hcl
terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  # Store state in S3 (not in Git)
  backend "s3" {
    # Configured via -backend-config flags in CI/CD
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

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

# Modules
module "networking" {
  source = "./modules/networking"

  environment = var.environment
  vpc_cidr    = var.vpc_cidr

  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "security" {
  source = "./modules/security"

  environment = var.environment
  account_id  = data.aws_caller_identity.current.account_id
}

module "rds" {
  source = "./modules/rds"

  environment            = var.environment
  database_name          = var.database_name
  master_username        = var.db_master_username
  master_password        = random_password.db_password.result
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  backup_retention_days  = var.db_backup_retention_days
  
  vpc_security_group_ids = [module.security.rds_security_group_id]
  db_subnet_group_name   = module.networking.db_subnet_group_name
}

module "eks" {
  source = "./modules/eks"

  environment         = var.environment
  cluster_name        = var.eks_cluster_name
  kubernetes_version  = var.kubernetes_version
  
  vpc_id              = module.networking.vpc_id
  private_subnet_ids  = module.networking.private_subnet_ids
  
  node_group_name     = "${var.environment}-nodes"
  desired_size        = var.node_group_desired_size
  min_size            = var.node_group_min_size
  max_size            = var.node_group_max_size
  instance_types      = var.node_group_instance_types

  iam_role_arn        = module.security.eks_role_arn
}

module "monitoring" {
  source = "./modules/monitoring"

  environment        = var.environment
  cluster_id         = module.eks.cluster_id
  cluster_endpoint   = module.eks.cluster_endpoint
  cluster_ca_cert    = module.eks.cluster_certificate
  
  prometheus_storage = var.prometheus_storage_gb
  retention_days     = var.metrics_retention_days
}

data "aws_caller_identity" "current" {}

# Password for RDS
resource "random_password" "db_password" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.environment}/db/master-password"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id       = aws_secretsmanager_secret.db_password.id
  secret_string   = random_password.db_password.result
}
```

### 2.2 Variables (terraform/variables.tf)

```hcl
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "database_name" {
  description = "Postgres database name"
  type        = string
  sensitive   = true
}

variable "db_master_username" {
  description = "Master username for RDS"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class (t3.medium, t3.large, etc)"
  type        = string
  default     = "t3.medium"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS (GB)"
  type        = number
  default     = 100
}

variable "db_backup_retention_days" {
  description = "Backup retention period"
  type        = number
  default     = 7
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.28"
}

variable "node_group_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 3
}

variable "node_group_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 10
}

variable "node_group_instance_types" {
  description = "EC2 instance types for worker nodes"
  type        = list(string)
  default     = ["t3.large", "t3.xlarge"]
}

variable "prometheus_storage_gb" {
  description = "Prometheus persistent storage (GB)"
  type        = number
  default     = 50
}

variable "metrics_retention_days" {
  description = "Metrics retention period"
  type        = number
  default     = 15
}
```

### 2.3 Outputs (terraform/outputs.tf)

```hcl
output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_id
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.endpoint
  sensitive   = true
}

output "rds_database_name" {
  description = "RDS database name"
  value       = var.database_name
}

output "db_master_username" {
  description = "RDS master username"
  value       = var.db_master_username
  sensitive   = true
}

output "prometheus_endpoint" {
  description = "Prometheus Grafana endpoint"
  value       = module.monitoring.prometheus_endpoint
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_id} --region ${var.aws_region}"
}
```

## Part 3: Module Example - EKS

### 3.1 EKS Module (terraform/modules/eks/main.tf)

```hcl
# IAM role for EKS cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServiceRolePolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name            = var.cluster_name
  version         = var.kubernetes_version
  role_arn        = aws_iam_role.eks_cluster_role.arn
  
  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  tags = {
    Name = var.cluster_name
  }
}

# IAM role for worker nodes
resource "aws_iam_role" "node_role" {
  name = "${var.environment}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_role.name
}

resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_role.name
}

resource "aws_iam_role_policy_attachment" "node_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_role.name
}

# EKS Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = var.private_subnet_ids
  version         = var.kubernetes_version

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  instance_types = var.instance_types

  tags = {
    Name = var.node_group_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_registry_policy,
  ]
}

# Cluster Autoscaler
resource "aws_iam_policy" "autoscaler" {
  name   = "${var.environment}-eks-autoscaler"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "ec2:DescribeLaunchConfigurationTypes",
          "ec2:DescribeInstanceTypes",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "autoscaler_policy" {
  policy_arn = aws_iam_policy.autoscaler.arn
  role       = aws_iam_role.node_role.name
}
```

## Part 4: Environment-Specific Configuration

### 4.1 Dev Environment (terraform/environments/dev/terraform.tfvars)

```hcl
environment   = "dev"
aws_region    = "us-east-1"
vpc_cidr      = "10.0.0.0/16"

public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

database_name         = "cardano_rwa_dev"
db_master_username    = "postgres"
db_instance_class     = "t3.micro"
db_allocated_storage  = 20
db_backup_retention_days = 1

eks_cluster_name     = "cardano-rwa-dev"
kubernetes_version   = "1.28"
node_group_desired_size = 1
node_group_min_size  = 1
node_group_max_size  = 3
node_group_instance_types = ["t3.medium"]

prometheus_storage_gb = 10
metrics_retention_days = 7
```

### 4.2 Production Environment (terraform/environments/prod/terraform.tfvars)

```hcl
environment   = "prod"
aws_region    = "us-east-1"
vpc_cidr      = "10.1.0.0/16"

# Multi-AZ subnets
public_subnet_cidrs  = [
  "10.1.1.0/24",    # us-east-1a
  "10.1.2.0/24",    # us-east-1b
  "10.1.3.0/24"     # us-east-1c
]
private_subnet_cidrs = [
  "10.1.10.0/24",   # us-east-1a
  "10.1.11.0/24",   # us-east-1b
  "10.1.12.0/24"    # us-east-1c
]

database_name         = "cardano_rwa_prod"
db_master_username    = "postgres"
db_instance_class     = "db.r6i.xlarge"    # High performance
db_allocated_storage  = 500
db_backup_retention_days = 30

eks_cluster_name     = "cardano-rwa-prod"
kubernetes_version   = "1.28"
node_group_desired_size = 5
node_group_min_size  = 3
node_group_max_size  = 20
node_group_instance_types = ["t3.xlarge", "t3.2xlarge"]

prometheus_storage_gb = 500
metrics_retention_days = 90
```

## Part 5: Deployment Script (terraform/scripts/apply.sh)

```bash
#!/bin/bash
set -e

ENVIRONMENT=${1:-dev}
AWS_REGION=${2:-us-east-1}
TERRAFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Usage: ./apply.sh {dev|staging|prod} [region]"
  exit 1
fi

echo "🚀 Deploying Terraform for environment: $ENVIRONMENT"

# Initialize Terraform
cd "$TERRAFORM_DIR"
terraform init \
  -backend-config="bucket=cardano-rwa-terraform-state" \
  -backend-config="key=environments/$ENVIRONMENT/terraform.tfstate" \
  -backend-config="region=$AWS_REGION" \
  -backend-config="encrypt=true" \
  -backend-config="dynamodb_table=terraform-lock"

# Plan changes
echo "📋 Planning infrastructure changes..."
terraform plan \
  -var-file="environments/$ENVIRONMENT/terraform.tfvars" \
  -var="aws_region=$AWS_REGION" \
  -out=tfplan

# Review
read -p "🔍 Review plan above. Continue? (yes/no) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "❌ Deployment cancelled"
  rm tfplan
  exit 1
fi

# Apply
echo "✅ Applying terraform configuration..."
terraform apply tfplan

# Output
echo ""
echo "📊 Outputs:"
terraform output

rm tfplan
echo "✨ Deployment complete!"
```

## Part 6: CI/CD Integration

### 6.1 GitHub Actions Workflow

Create `.github/workflows/terraform-deploy.yml`:

```yaml
name: Terraform Deploy

on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'
  pull_request:
    paths:
      - 'terraform/**'

jobs:
  terraform:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, prod]
    environment:
      name: ${{ matrix.environment }}

    steps:
      - uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Initialize Terraform
        run: |
          cd terraform
          terraform init \
            -backend-config="bucket=cardano-rwa-terraform-state" \
            -backend-config="key=environments/${{ matrix.environment }}/terraform.tfstate" \
            -backend-config="region=us-east-1" \
            -backend-config="encrypt=true" \
            -backend-config="dynamodb_table=terraform-lock"

      - name: Format Check
        run: |
          cd terraform
          terraform fmt -check -recursive

      - name: Validate
        run: |
          cd terraform
          terraform validate

      - name: Plan
        run: |
          cd terraform
          terraform plan \
            -var-file="environments/${{ matrix.environment }}/terraform.tfvars" \
            -var="aws_region=us-east-1" \
            -out=tfplan

      - name: Upload Plan
        if: github.event_name == 'pull_request'
        uses: actions/upload-artifact@v3
        with:
          name: tfplan-${{ matrix.environment }}
          path: terraform/tfplan

      - name: Comment PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '✅ Terraform plan for `${{ matrix.environment }}` complete. See artifacts.'
            })

      - name: Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: |
          cd terraform
          terraform apply -auto-approve tfplan
```

## Part 7: GitOps with ArgoCD

### 7.1 Deploy ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 7.2 Application Definition

Create `k8s/argocd/cardano-rwa-app.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cardano-rwa
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/cardano-rwa/core
    path: k8s/
    targetRevision: main
    
  destination:
    server: https://kubernetes.default.svc
    namespace: cardano-rwa
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Success Criteria (for Gap #7 closure)

✅ Multi-environment Terraform configuration (dev, staging, prod)  
✅ Modular HCL with reusable modules  
✅ State management with S3 backend + DynamoDB lock  
✅ Automated validation and formatting in CI/CD  
✅ GitOps deployment with ArgoCD  
✅ Secret management (AWS Secrets Manager)  
✅ Monitoring and alerts configured via IaC  
✅ Blue-green deployment capability  
✅ < 5 minute deployment time  
✅ Team trained on Terraform workflow  
