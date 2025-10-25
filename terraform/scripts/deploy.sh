#!/bin/bash

# EM NextGen Infrastructure Deployment Script
# Usage: ./scripts/deploy.sh <product> <environment> <action>
# Example: ./scripts/deploy.sh baml walmart plan

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 <product> <environment> <action>

Products:
  - em
  - baml
  - em_nextgen

Environments:
  - dev
  - prod
  - cs (baml only)
  - walmart (baml only)

Actions:
  - init     : Initialize Terraform
  - validate : Validate Terraform configuration
  - plan     : Create execution plan
  - apply    : Apply changes
  - destroy  : Destroy infrastructure
  - output   : Show outputs

Examples:
  $0 baml walmart plan
  $0 em dev apply
  $0 baml prod destroy

EOF
    exit 1
}

# Check arguments
if [ $# -lt 3 ]; then
    print_error "Missing arguments"
    usage
fi

PRODUCT=$1
ENVIRONMENT=$2
ACTION=$3

# Validate product
case $PRODUCT in
    em|baml|em_nextgen)
        ;;
    *)
        print_error "Invalid product: $PRODUCT"
        usage
        ;;
esac

# Validate environment
case $ENVIRONMENT in
    dev|prod)
        ;;
    cs|walmart)
        if [ "$PRODUCT" != "baml" ]; then
            print_error "Environment $ENVIRONMENT is only available for baml product"
            usage
        fi
        ;;
    *)
        print_error "Invalid environment: $ENVIRONMENT"
        usage
        ;;
esac

# Validate action
case $ACTION in
    init|validate|plan|apply|destroy|output)
        ;;
    *)
        print_error "Invalid action: $ACTION"
        usage
        ;;
esac

# Set variables
TFVARS_FILE="environments/${PRODUCT}/${ENVIRONMENT}.tfvars"
WORKSPACE="${PRODUCT}-${ENVIRONMENT}"

# Check if tfvars file exists
if [ ! -f "$TFVARS_FILE" ]; then
    print_error "Configuration file not found: $TFVARS_FILE"
    exit 1
fi

print_info "============================================"
print_info "EM NextGen Infrastructure Deployment"
print_info "============================================"
print_info "Product: $PRODUCT"
print_info "Environment: $ENVIRONMENT"
print_info "Action: $ACTION"
print_info "Config File: $TFVARS_FILE"
print_info "Workspace: $WORKSPACE"
print_info "============================================"

# Change to terraform directory
cd "$(dirname "$0")/.."

# Execute Terraform commands
case $ACTION in
    init)
        print_info "Initializing Terraform..."
        terraform init

        # Create or select workspace
        if terraform workspace list | grep -q "$WORKSPACE"; then
            print_info "Selecting workspace: $WORKSPACE"
            terraform workspace select "$WORKSPACE"
        else
            print_info "Creating workspace: $WORKSPACE"
            terraform workspace new "$WORKSPACE"
        fi
        ;;

    validate)
        print_info "Validating Terraform configuration..."
        terraform validate
        ;;

    plan)
        print_info "Creating execution plan..."
        terraform workspace select "$WORKSPACE" 2>/dev/null || terraform workspace new "$WORKSPACE"
        terraform plan -var-file="$TFVARS_FILE" -out=tfplan
        print_info "Plan saved to tfplan"
        ;;

    apply)
        print_warn "This will apply changes to $PRODUCT $ENVIRONMENT environment"
        read -p "Are you sure you want to continue? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            print_error "Aborted by user"
            exit 1
        fi

        print_info "Applying changes..."
        terraform workspace select "$WORKSPACE" 2>/dev/null || terraform workspace new "$WORKSPACE"

        if [ -f "tfplan" ]; then
            print_info "Using existing plan file..."
            terraform apply tfplan
        else
            print_warn "No plan file found, creating new plan..."
            terraform apply -var-file="$TFVARS_FILE"
        fi
        ;;

    destroy)
        print_warn "⚠️  WARNING: This will DESTROY all resources in $PRODUCT $ENVIRONMENT environment ⚠️"
        read -p "Type 'destroy' to confirm: " confirm
        if [ "$confirm" != "destroy" ]; then
            print_error "Aborted by user"
            exit 1
        fi

        print_info "Destroying infrastructure..."
        terraform workspace select "$WORKSPACE" 2>/dev/null || terraform workspace new "$WORKSPACE"
        terraform destroy -var-file="$TFVARS_FILE"
        ;;

    output)
        print_info "Showing outputs..."
        terraform workspace select "$WORKSPACE" 2>/dev/null || terraform workspace new "$WORKSPACE"
        terraform output
        ;;
esac

print_info "============================================"
print_info "Action completed successfully!"
print_info "============================================"
