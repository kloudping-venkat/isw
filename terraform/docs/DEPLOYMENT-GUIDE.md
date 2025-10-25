# EM NextGen Infrastructure Deployment Guide

## Directory Structure

```
terraform/
├── docs/                           # Documentation files
├── environments/                   # Environment-specific configurations
│   ├── em/                        # EM product configurations
│   │   ├── dev.tfvars            # Development environment
│   │   └── prod.tfvars           # Production environment
│   ├── baml/                      # BAML product configurations
│   │   ├── cs.tfvars             # CS environment
│   │   ├── dev.tfvars            # Development environment
│   │   ├── prod.tfvars           # Production environment
│   │   └── walmart.tfvars        # Walmart environment
│   └── em_nextgen/                # EM NextGen product configurations
│       ├── dev.tfvars            # Development environment
│       └── prod.tfvars           # Production environment
├── modules/                       # Terraform modules
│   └── azure/                     # Azure-specific modules
│       ├── aks/                  # Azure Kubernetes Service
│       ├── application-gateway/   # Application Gateway
│       ├── compute/              # Virtual Machines
│       ├── db/                   # Database resources
│       ├── keyvault/             # Key Vault
│       ├── nat-gateway/          # NAT Gateway
│       ├── networking/           # VNet, Subnets, NSGs
│       ├── rg/                   # Resource Groups
│       ├── sftp/                 # SFTP storage
│       ├── storage-scripts/      # Storage account scripts
│       ├── vnet-peering/         # VNet Peering
│       └── vpn-gateway/          # VPN Gateway
├── powershell/                    # PowerShell scripts
├── scripts/                       # Deployment scripts
├── backend.tf                     # Backend configuration
├── main.tf                        # Main infrastructure code
├── outputs.tf                     # Output definitions
├── provider.tf                    # Provider configuration
├── README.md                      # Main README
├── shared-vars.tf                 # Shared variables
└── variables.tf                   # Variable definitions
```

## Deployment Methods

### Method 1: Azure DevOps Pipeline (Recommended)

The pipeline provides dropdown selectors for easy deployment:

1. **Navigate to Azure DevOps Pipeline**
   - Go to your Azure DevOps project
   - Navigate to Pipelines
   - Select "EM NextGen Infrastructure" pipeline

2. **Run Pipeline with Parameters**
   - Click "Run pipeline"
   - Select parameters from dropdowns:
     - **Product/Client**: Choose from `em`, `baml`, or `em_nextgen`
     - **Environment**: Choose from `dev`, `prod`, `cs`, or `walmart`
     - **Terraform Action**: Choose from `plan`, `apply`, or `destroy`
     - **Auto Approve**: Check to skip manual approval (use with caution)

3. **Pipeline Stages**
   - **Validate and Plan**: Validates Terraform code and creates execution plan
   - **Apply**: Applies changes (only if action is 'apply')
   - **Destroy**: Destroys infrastructure (only if action is 'destroy')

### Method 2: Local Deployment

#### Prerequisites
- Terraform installed (v1.5.7 or later)
- Azure CLI installed and authenticated
- Appropriate Azure permissions

#### Steps

1. **Navigate to terraform directory**
   ```bash
   cd terraform
   ```

2. **Initialize Terraform**
   ```bash
   terraform init
   ```

3. **Select workspace (optional)**
   ```bash
   terraform workspace new baml-prod
   terraform workspace select baml-prod
   ```

4. **Plan deployment**
   ```bash
   # For BAML Production
   terraform plan -var-file="environments/baml/prod.tfvars"

   # For EM Development
   terraform plan -var-file="environments/em/dev.tfvars"

   # For Walmart
   terraform plan -var-file="environments/baml/walmart.tfvars"
   ```

5. **Apply changes**
   ```bash
   # For BAML Production
   terraform apply -var-file="environments/baml/prod.tfvars"

   # For EM Development
   terraform apply -var-file="environments/em/dev.tfvars"
   ```

6. **Destroy infrastructure (if needed)**
   ```bash
   terraform destroy -var-file="environments/baml/prod.tfvars"
   ```

## Environment Configuration

### Product-Environment Matrix

| Product    | Available Environments          |
|------------|---------------------------------|
| em         | dev, prod                       |
| baml       | dev, prod, cs, walmart          |
| em_nextgen | dev, prod                       |

### Configuration Files

Each `.tfvars` file contains environment-specific values:

- Network configuration (VNet address spaces, subnets)
- Resource sizing (VM sizes, disk sizes)
- Security settings (firewall rules, private endpoints)
- Feature flags (enable/disable components)
- Tags and metadata

### Example: Deploying to BAML Walmart Environment

**Using Azure DevOps Pipeline:**
1. Run pipeline
2. Select: Product = `baml`, Environment = `walmart`, Action = `plan`
3. Review plan output
4. Run again with Action = `apply` if plan looks good

**Using Local Terraform:**
```bash
cd terraform
terraform init
terraform plan -var-file="environments/baml/walmart.tfvars"
terraform apply -var-file="environments/baml/walmart.tfvars"
```

## Backend Configuration

The Terraform state is stored in Azure Storage with separate state files per product-environment:

- State file naming: `{product}-{environment}.tfstate`
- Examples:
  - `baml-prod.tfstate`
  - `em-dev.tfstate`
  - `baml-walmart.tfstate`

Update `backend.tf` with your storage account details:
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstatestorage"
    container_name       = "tfstate"
    key                  = "{product}-{environment}.tfstate"  # This is set dynamically
  }
}
```

## Adding New Products or Environments

### Add New Product

1. Create product directory:
   ```bash
   mkdir -p terraform/environments/new_product
   ```

2. Create environment files:
   ```bash
   touch terraform/environments/new_product/dev.tfvars
   touch terraform/environments/new_product/prod.tfvars
   ```

3. Update pipeline parameters in `azure-pipelines.yml`:
   ```yaml
   - name: product
     values:
       - em
       - baml
       - em_nextgen
       - new_product  # Add here
   ```

### Add New Environment

1. Create tfvars file for the product:
   ```bash
   touch terraform/environments/baml/staging.tfvars
   ```

2. Update pipeline parameters in `azure-pipelines.yml`:
   ```yaml
   - name: environment
     values:
       - dev
       - prod
       - cs
       - walmart
       - staging  # Add here
   ```

## Best Practices

1. **Always run plan before apply**
   - Review all changes before applying
   - Verify resource counts and modifications

2. **Use workspaces for isolation**
   - Keep separate state files per environment
   - Avoid state conflicts

3. **Version control**
   - Commit all `.tfvars` changes
   - Use meaningful commit messages
   - Create PRs for production changes

4. **Security**
   - Never commit secrets to `.tfvars` files
   - Use Azure Key Vault for sensitive data
   - Rotate credentials regularly

5. **Testing**
   - Test in dev environment first
   - Validate changes in lower environments
   - Use approval gates for production

## Troubleshooting

### Common Issues

**Issue: Module not found**
```
Error: Module not found: ./modules/em
```
**Solution**: Modules have been reorganized to `./modules/azure`. Update any custom references.

**Issue: Variable not defined**
```
Error: Variable not declared
```
**Solution**: Ensure all required variables are defined in your `.tfvars` file. Check `variables.tf` for required variables.

**Issue: State lock**
```
Error: Error acquiring the state lock
```
**Solution**: Wait for other operations to complete or manually release the lock in Azure Storage.

## Support

For issues or questions:
1. Check this documentation
2. Review the main README.md
3. Check docs/ directory for specific component documentation
4. Contact the CloudOps team
