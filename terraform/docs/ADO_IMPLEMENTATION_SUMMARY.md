# ✅ Azure DevOps Agent Integration - Windows Only Implementation

## 🎯 Requirements Met

### ✅ **Functional Requirements**
- **Agent Installation**: ✅ Installs on Windows VMs during provisioning
- **Service Configuration**: ✅ Runs as Windows service (auto-start)
- **Deployment Group**: ✅ Registers to EM-BOFA-PROD
- **Tagging**: ✅ Supports role-based tags (WEB, APP, ADO, EMPRODBOFA, etc.)

### ✅ **Security Requirements**
- **PAT Management**: ✅ Uses Azure DevOps pipeline variables (no hardcoded secrets)
- **Secure Transmission**: ✅ PAT passed via protected VM extension settings
- **No Code Secrets**: ✅ No credentials in Terraform files

### ✅ **Technical Implementation**
- **VM Extension**: ✅ Uses CustomScriptExtension for Windows
- **Embedded Scripts**: ✅ PowerShell script embedded in Terraform
- **Error Handling**: ✅ Comprehensive logging and error reporting
- **Idempotent**: ✅ Safe to run multiple times

## 📁 **Files Created/Modified**

### **New Files**:
```
terraform/modules/em/compute/agent-install.tf          # Main ADO agent extension
terraform/modules/em/compute/scripts/install-agent-windows.ps1  # Standalone script
ADO_PIPELINE_CONFIGURATION.md                          # Pipeline setup guide
```

### **Modified Files**:
```
terraform/variables.tf                                 # Added ADO variables
terraform/main.tf                                     # Added agent config to VMs
terraform/modules/em/variables.tf                     # Added ADO module variables  
terraform/modules/em/main.tf                          # Passed ADO params to compute
terraform/modules/em/compute/variables.tf             # Added compute ADO variables
```

## 🔧 **Configuration Example**

### **VM Configuration with ADO Agent**:
```hcl
virtual_machines = {
  "${local.prefix}-WEB-VM01" = {
    # ... standard VM config ...
    
    # Azure DevOps Agent Configuration
    install_ado_agent = true
    ado_agent_tags   = "WEB,WEB11,EMPRODBOFA"
  }
}
```

### **Pipeline Variables Required**:
```yaml
variables:
  TF_VAR_azdo_org_url: 'https://dev.azure.com/your-org'
  TF_VAR_deployment_group_name: 'EM-BOFA-PROD'
  # Secret variable:
  TF_VAR_azdo_pat: $(secret-ado-pat-token)
```

## 🚀 **Deployment Process**

### **1. Configure Pipeline Variables**
- Set `TF_VAR_azdo_pat` as secret variable in Azure DevOps
- Set organization URL and deployment group name
- Ensure PAT has required scopes (Deployment Groups: Read & Manage)

### **2. Enable Agent Installation**
- Set `install_ado_agent = true` on desired VMs
- Configure appropriate tags for each VM role
- Run Terraform plan/apply

### **3. Verify Installation**
- Check Azure DevOps deployment group for new agents
- Verify agents show as "Online"
- Confirm correct tags are applied

## 📊 **VM Configurations**

### **WEB Servers**:
- **Tags**: `WEB,WEB11,EMPRODBOFA`
- **Purpose**: Web application deployments
- **Agent Name**: VM hostname (e.g., US1-BOFA-CS-WEB-VM01)

### **APP Servers**:
- **Tags**: `APP,EMPRODBOFA`
- **Purpose**: Application tier deployments
- **Agent Name**: VM hostname (e.g., US1-BOFA-CS-APP-VM01)

### **ADO Servers**:
- **Tags**: `ADO,EMPRODBOFA,EMUATBOFA`
- **Purpose**: Build and deployment agents
- **Agent Name**: VM hostname (e.g., US1-BOFA-CS-ADO-VM01)

## 🛡️ **Security Features**

### **PAT Token Security**:
- ✅ **Never in code**: Passed via pipeline variables only
- ✅ **Encrypted transit**: Protected VM extension settings
- ✅ **Scoped permissions**: Only required ADO permissions
- ✅ **Auditable**: All access logged in Azure DevOps

### **Agent Security**:
- ✅ **Service account**: Runs as NT AUTHORITY\SYSTEM
- ✅ **Automatic startup**: Configured as Windows service
- ✅ **Secure communication**: TLS to Azure DevOps

## 📈 **Benefits**

### **Operational**:
- **Automated deployment**: No manual agent installation
- **Consistent configuration**: Same setup across all VMs
- **Role-based targeting**: Deploy to specific VM types via tags
- **Self-healing**: Service auto-restarts with VM

### **Security**:
- **No credential management on VMs**: PAT handled by Azure DevOps
- **Centralized control**: Manage all agents from Azure DevOps
- **Audit trail**: Full deployment history in pipelines

### **Scalability**:
- **Easy expansion**: Add new VMs with agent automatically
- **Tag-based targeting**: Flexible deployment strategies
- **Consistent naming**: Predictable agent names

## 🎉 **Ready for Production**

The implementation meets all requirements and is ready for deployment:

1. **Set pipeline variables** for PAT token and organization
2. **Enable agent installation** on desired VMs
3. **Deploy via Terraform** pipeline
4. **Verify agents** appear in EM-BOFA-PROD deployment group

Agents will automatically register and be ready for deployment jobs! 🚀