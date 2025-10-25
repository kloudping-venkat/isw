# Azure DevOps Pipeline Configuration for PAT Token
# This document explains how to configure Azure DevOps pipeline variables

## Required Pipeline Variables

### 1. Secret Variable in Azure DevOps
Create a secret variable in your Azure DevOps pipeline:

**Variable Name**: `TF_VAR_azdo_pat`
**Type**: Secret
**Value**: Your Azure DevOps Personal Access Token
**Scope**: Required scopes:
- Deployment Groups: Read & Manage
- Agent Pools: Read & Manage

### 2. Pipeline YAML Configuration

Add this to your Azure DevOps pipeline YAML:

```yaml
variables:
  # Public variables
  TF_VAR_azdo_org_url: 'https://dev.azure.com/your-organization'
  TF_VAR_deployment_group_name: 'EM-BOFA-PROD'
  
  # Secret variable (configured in Azure DevOps UI)
  # TF_VAR_azdo_pat: $(secret-ado-pat-token)

steps:
  - task: TerraformTaskV4@4
    displayName: 'Terraform Apply'
    inputs:
      command: 'apply'
      workingDirectory: '$(Build.SourcesDirectory)/terraform'
      environmentServiceNameAzureRM: 'your-service-connection'
      commandOptions: '-var-file="environments/cs.tfvars"'
    env:
      TF_VAR_azdo_pat: $(secret-ado-pat-token)  # Secret variable
      TF_VAR_azdo_org_url: $(TF_VAR_azdo_org_url)
      TF_VAR_deployment_group_name: $(TF_VAR_deployment_group_name)
```

### 3. Alternative: Variable Groups

You can also use Variable Groups:

1. **Create Variable Group**: "ADO-Agent-Config"
2. **Add Variables**:
   - `azdo_org_url`: https://dev.azure.com/your-organization
   - `azdo_pat`: [Secret] Your PAT token
   - `deployment_group_name`: EM-BOFA-PROD

3. **Reference in Pipeline**:
```yaml
variables:
  - group: ADO-Agent-Config

steps:
  - task: TerraformTaskV4@4
    inputs:
      command: 'apply'
      commandOptions: '-var="azdo_pat=$(azdo_pat)" -var="azdo_org_url=$(azdo_org_url)"'
```

## Security Benefits

✅ **No secrets in code**: PAT token never stored in Terraform files
✅ **Azure DevOps managed**: Uses Azure DevOps secret management
✅ **Scoped access**: PAT token only has required permissions
✅ **Audit trail**: Azure DevOps logs all secret access
✅ **Rotation friendly**: Easy to update PAT token in one place

## Required PAT Permissions

When creating your PAT token, ensure these scopes:

- **Deployment Groups**: Read & Manage
- **Agent Pools**: Read & Manage  
- **Project and Team**: Read (for API access)

## Testing

To test your setup:

1. **Set pipeline variables** as described above
2. **Run pipeline** with `plan-only` first
3. **Verify** no validation errors for ADO variables
4. **Run** with `plan-and-apply` to deploy agents
5. **Check** Azure DevOps deployment group for new agents

## Troubleshooting

**Common Issues**:
- Variable not set: Check TF_VAR_azdo_pat is configured as secret
- Permission denied: Verify PAT token has correct scopes
- Org URL wrong: Ensure format is https://dev.azure.com/your-org
- Deployment group not found: Create the group first in Azure DevOps