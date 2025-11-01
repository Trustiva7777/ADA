#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Enterprise Deployment Script (Phase 1-3)
# ═══════════════════════════════════════════════════════════════════════════

set -e

ENVIRONMENT=${1:-dev}
AWS_REGION=${2:-us-east-1}
ACTION=${3:-plan}  # plan, apply, destroy

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚀 Enterprise Deployment Script${NC}"
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo "Action: $ACTION"
echo ""

# Validate inputs
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}❌ Invalid environment. Must be dev, staging, or prod.${NC}"
    exit 1
fi

cd terraform

# Initialize Terraform
echo -e "${YELLOW}📦 Initializing Terraform...${NC}"
terraform init \
    -backend-config="bucket=cardano-rwa-tf-state" \
    -backend-config="key=env/$ENVIRONMENT/terraform.tfstate" \
    -backend-config="region=$AWS_REGION" \
    -backend-config="dynamodb_table=cardano-rwa-tf-lock"

# Format check
echo -e "${YELLOW}📝 Formatting Terraform files...${NC}"
terraform fmt -recursive

# Validate
echo -e "${YELLOW}✓ Validating Terraform configuration...${NC}"
terraform validate

# Plan
echo -e "${YELLOW}📋 Planning deployment...${NC}"
terraform plan \
    -var-file="$ENVIRONMENT.tfvars" \
    -var="aws_region=$AWS_REGION" \
    -out="$ENVIRONMENT.tfplan"

# Apply or Destroy
case $ACTION in
    plan)
        echo -e "${GREEN}✅ Plan completed. Review the output above.${NC}"
        echo "Run with 'apply' action to deploy."
        ;;
    apply)
        echo -e "${YELLOW}⚠️  Applying changes to $ENVIRONMENT...${NC}"
        read -p "Are you sure? (yes/no): " -r CONFIRM
        if [[ $CONFIRM == "yes" ]]; then
            terraform apply "$ENVIRONMENT.tfplan"
            echo -e "${GREEN}✅ Infrastructure deployed successfully!${NC}"
            
            # Output important values
            echo ""
            echo -e "${YELLOW}📊 Infrastructure Details:${NC}"
            terraform output -json > "$ENVIRONMENT-outputs.json"
            echo "Outputs saved to $ENVIRONMENT-outputs.json"
            
            # Show key outputs
            echo ""
            echo "EKS Cluster Endpoint: $(terraform output -raw eks_cluster_endpoint 2>/dev/null || echo 'N/A')"
            echo "RDS Endpoint: $(terraform output -raw rds_endpoint 2>/dev/null || echo 'N/A')"
        else
            echo -e "${RED}❌ Deployment cancelled.${NC}"
            exit 1
        fi
        ;;
    destroy)
        echo -e "${RED}⚠️  WARNING: This will destroy all infrastructure in $ENVIRONMENT!${NC}"
        read -p "Type 'destroy-$ENVIRONMENT' to confirm: " -r CONFIRM
        if [[ $CONFIRM == "destroy-$ENVIRONMENT" ]]; then
            terraform destroy \
                -var-file="$ENVIRONMENT.tfvars" \
                -var="aws_region=$AWS_REGION" \
                -auto-approve
            echo -e "${GREEN}✅ Infrastructure destroyed.${NC}"
        else
            echo -e "${RED}❌ Destruction cancelled.${NC}"
            exit 1
        fi
        ;;
    *)
        echo -e "${RED}❌ Unknown action: $ACTION${NC}"
        echo "Usage: $0 <environment> <region> <plan|apply|destroy>"
        exit 1
        ;;
esac

cd ..

echo ""
echo -e "${GREEN}🎉 Deployment script completed!${NC}"
