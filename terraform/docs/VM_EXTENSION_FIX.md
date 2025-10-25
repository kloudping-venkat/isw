# VM Extension Configuration Fix

## Issues Identified

1. **VM Extensions were disabled** - The `enable_vm_extensions` parameter was not being passed to the compute modules
2. **Missing ADO configuration** - ADO organization URL and deployment group were not configured
3. **NAT Gateway was disabled** - VMs couldn't reach the internet for package downloads

## Fixes Applied

### 1. NAT Gateway Configuration (for internet access)
```hcl
# In terraform/main.tf line 122-124
create_nat_gateway       = true
nat_gateway_subnet_names = ["WEB-SUBNET", "APP-SUBNET", "ADO-SUBNET"]
```

### 2. VM Extensions Enabled
```hcl
# Added to all VM modules in terraform/main.tf
enable_vm_extensions = true
ado_organization_url = var.ado_organization_url
ado_deployment_group = var.ado_deployment_group
```

### 3. ADO Configuration Added
```hcl
# In terraform/environments/cs.tfvars
ado_organization_url = "https://dev.azure.com/your-organization"
ado_deployment_group = "EMPRODBOFA"
```

## What VM Extensions Will Install

### For WEB VMs (Role = "WebServer"):
- **IIS Web Server** with management tools
- **ASP.NET 4.5** features
- **Default website** with custom page
- **Data disks** (128GB → E:, 50GB → R:)
- **Azure DevOps Agent** (if configured)

### For APP VMs (Role = "ApplicationServer"):
- **.NET Framework 4.5** features
- **Data disks** (128GB → E:, 50GB → R:)
- **Azure DevOps Agent** (if configured)

### For ADO VMs (Role = "ADOAgent"):
- **.NET Framework 4.5** features
- **PowerShell ISE**
- **Data disks** (128GB → E:, 128GB → R:)
- **Azure DevOps Agent** configured for deployment groups

## Verification Commands (After Next Deployment)

### 1. Check VM Extension Status
```powershell
# Check if extension ran
Test-Path "C:\temp\vm_configuration.log"
Get-Content "C:\temp\vm_configuration.log" | Select-Object -Last 10

# Check Azure extension logs
$path = "C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension"
Get-ChildItem "$path\*\*\CommandExecution.log" | Sort LastWriteTime | Select -Last 1 | Get-Content | Select -Last 15
```

### 2. Check Data Disks
```powershell
# Should show C:, D:, E:, R:, and X: (DVD moved to X:)
Get-Volume | Where-Object { $_.DriveLetter -ne $null } | Sort-Object DriveLetter
```

### 3. Check IIS (WEB VMs only)
```powershell
# Check IIS installation
Get-WindowsFeature | Where-Object {$_.Name -eq "Web-Server"}
Get-Service W3SVC
Get-Website

# Test website
Invoke-WebRequest -Uri "http://localhost" -UseBasicParsing
```

### 4. Check Internet Connectivity
```powershell
# Should work with NAT Gateway
Test-NetConnection -ComputerName "8.8.8.8" -Port 53
Test-NetConnection -ComputerName "google.com" -Port 80
```

### 5. Check ADO Agent (if configured)
```powershell
# Check agent installation
Get-ChildItem "C:\ADOAgent"
Get-Service -Name "*vsts*"
Get-Content "C:\ADOAgent\install_success.json" -ErrorAction SilentlyContinue
```

## Next Steps

1. **Update ADO URL** in `terraform/environments/cs.tfvars` with your actual Azure DevOps organization URL
2. **Run your Terraform pipeline** to apply these changes
3. **Verify the installation** using the commands above
4. **Check Azure DevOps** deployment groups to see if agents appear

## Important Notes

- VMs will restart during extension installation
- Data disk provisioning takes 2-3 minutes
- IIS installation may take 5-10 minutes
- ADO agent requires valid PAT token (stored in Key Vault)
- Internet connectivity requires NAT Gateway to be deployed first

The extension creates a comprehensive log at `C:\temp\vm_configuration.log` showing all installation steps.