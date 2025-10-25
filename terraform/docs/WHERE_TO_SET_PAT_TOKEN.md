# 🔑 Where to Set PAT Token - Step by Step Guide

## Method 1: Pipeline Variables (Recommended)

### Step 1: Go to Your Azure DevOps Pipeline
1. Navigate to **Azure DevOps** → **Pipelines** 
2. Find your **Terraform pipeline** (cs-azure-pipeline)
3. Click **Edit** on the pipeline

### Step 2: Add Pipeline Variable
1. Click **Variables** button (top right of pipeline editor)
2. Click **New variable**
3. Fill in:
   - **Name**: `TF_VAR_azdo_pat`
   - **Value**: `[Your PAT Token]` 
   - **✅ Keep this value secret**: **CHECKED**
   - **Scope**: Pipeline

### Step 3: Save the Variable
1. Click **OK**
2. Click **Save** to save the pipeline

## Method 2: Variable Groups (Alternative)

### Step 1: Create Variable Group
1. Go to **Azure DevOps** → **Pipelines** → **Library**
2. Click **+ Variable group**
3. Name: `ADO-Agent-Secrets`

### Step 2: Add Variables
Add these variables to the group:
- **Name**: `azdo_pat` | **Value**: `[Your PAT Token]` | **Secret**: ✅
- **Name**: `azdo_org_url` | **Value**: `https://dev.azure.com/your-org`
- **Name**: `deployment_group_name` | **Value**: `EM-BOFA-PROD`

### Step 3: Reference in Pipeline
Add this to your pipeline YAML:
```yaml
variables:
  - group: ADO-Agent-Secrets
```

## Method 3: Direct in Pipeline YAML

Add this to your `cs-azure-pipeline.yml`:

```yaml
# Add this to your existing pipeline
variables:
  # Set these as pipeline variables in Azure DevOps UI
  TF_VAR_azdo_org_url: 'https://dev.azure.com/your-organization'
  TF_VAR_deployment_group_name: 'EM-BOFA-PROD'

stages:
  - stage: TerraformPipeline
    jobs:
      - job: TerraformDeployment
        steps:
          - template: templates/apply.yml
            parameters:
              environment: ${{ parameters.environment }}
              workingDirectory: ${{ parameters.workingDirectory }}
            # The secret variable TF_VAR_azdo_pat will be automatically passed
```

## 🎯 **Recommended Approach: Pipeline Variables**

**Why Pipeline Variables are Best:**
- ✅ **Simplest setup** - Just add one secret variable
- ✅ **Secure** - Encrypted and masked in logs  
- ✅ **Pipeline-specific** - Isolated to your pipeline
- ✅ **Easy to update** - Change in one place

## 📋 **Required PAT Token Setup**

### Step 1: Create PAT Token
1. Go to **Azure DevOps** → **User Settings** → **Personal Access Tokens**
2. Click **New Token**
3. **Name**: `Terraform-ADO-Agents`
4. **Scopes**: Select these:
   - ✅ **Deployment Groups**: Read & Manage
   - ✅ **Agent Pools**: Read & Manage

### Step 2: Copy Token
- **Copy the token immediately** (you won't see it again)
- Store it temporarily in a secure location

### Step 3: Add to Pipeline Variable
- Use the token value in `TF_VAR_azdo_pat` pipeline variable

## ✅ **Verification**

After setting up, verify:

1. **Pipeline Variables**: Check that `TF_VAR_azdo_pat` shows as `***` (hidden)
2. **Run Pipeline**: Execute a plan to ensure no validation errors
3. **Check Logs**: Terraform should not show any "variable not set" errors for ADO variables

## 🚨 **Important Notes**

- **Never commit PAT tokens to code**
- **Use pipeline variables only**
- **Keep PAT tokens as secrets** (checked box)
- **Rotate PAT tokens regularly** (recommended every 90 days)

## 🎬 **Quick Visual Guide**

```
Azure DevOps → Your Pipeline → Edit → Variables → New Variable
┌─────────────────────────────────────────┐
│ Name: TF_VAR_azdo_pat                   │
│ Value: [paste your PAT token here]     │
│ ✅ Keep this value secret              │
│ Scope: Pipeline                         │
└─────────────────────────────────────────┘
```

That's it! The pipeline will automatically pass this as an environment variable to Terraform. 🎉