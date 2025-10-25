# Quick Reference - PAT Token Setup

## 📍 **WHERE**: Azure DevOps Pipeline Variables

### 🎯 **Exact Location**:
1. **Azure DevOps** portal
2. **Pipelines** section  
3. **Your cs-azure-pipeline**
4. **Edit** → **Variables** button
5. **New variable**

### 🔑 **Variable Details**:
```
Name: TF_VAR_azdo_pat
Value: [Your PAT Token - paste here]
✅ Keep this value secret: CHECKED
Scope: Pipeline
```

### 📝 **Required PAT Scopes**:
When creating your PAT token in Azure DevOps:
- ✅ **Deployment Groups**: Read & Manage
- ✅ **Agent Pools**: Read & Manage

### 🔄 **Process**:
1. **Create PAT** in Azure DevOps → User Settings → Personal Access Tokens
2. **Copy token** (save immediately - you won't see it again!)
3. **Add to pipeline** as secret variable `TF_VAR_azdo_pat`
4. **Run pipeline** - agents will install automatically

### ✅ **Verification**:
- Variable shows as `***` in pipeline (hidden)
- No "variable not set" errors in Terraform logs
- Agents appear in EM-BOFA-PROD deployment group after deployment

**That's it! No Key Vault, no code changes needed - just one pipeline variable.** 🎉