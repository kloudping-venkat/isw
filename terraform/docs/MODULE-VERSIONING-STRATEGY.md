# Module Versioning Strategy

## Overview

This document explains why we use **local module references** instead of git-based module sources for the EM NextGen Infrastructure.

## Module Reference Approaches

### Approach 1: Git-Based Module Sources (Not Used)

```hcl
module "spoke_vnet" {
  source = "git::https://dev.azure.com/insight-certent/CLOUDOPS/_git/EM.NextGen-IaC//terraform/modules/azure?ref=v1.0.0"
}

module "sftp" {
  source = "git::https://dev.azure.com/insight-certent/CLOUDOPS/_git/EM.NextGen-IaC//terraform/modules/azure/sftp?ref=v1.0.0"
}
```

**Format:**
- `git::https://` - Protocol (HTTPS) or `git::ssh://` for SSH
- `dev.azure.com/org/project/_git/repo` - Repository URL
- `//path/to/module` - Path within repo (double slash after repo URL)
- `?ref=v1.0.0` - Git reference (tag, branch, or commit SHA)

**Benefits:**
- ✅ Explicit version control per module
- ✅ Different environments can use different module versions
- ✅ Modules can be shared across multiple repositories
- ✅ Fine-grained version control (can update one module at a time)
- ✅ True semantic versioning for modules

**Drawbacks:**
- ❌ Need to update `ref` in code when upgrading modules
- ❌ More complex to manage (multiple version numbers to track)
- ❌ Authentication required (Azure DevOps PAT token or SSH keys)
- ❌ Terraform downloads modules separately (slower `terraform init`)
- ❌ Must run `terraform init -upgrade` to get new module versions
- ❌ Harder to develop/test module changes (need to commit/tag before testing)
- ❌ Version drift risk (different environments accidentally use different versions)

### Approach 2: Local Module References (Current Approach)

```hcl
module "spoke_vnet" {
  source = "./modules/azure"
}

module "sftp" {
  source = "./modules/azure/sftp"
}
```

**Benefits:**
- ✅ Simple - no version tracking needed in module sources
- ✅ Entire environment (code + modules) versioned together via git branch/tag
- ✅ No authentication issues
- ✅ Faster `terraform init` (no downloads)
- ✅ Easy to develop/test module changes locally
- ✅ Single version number for entire stack (branch or tag)
- ✅ No version drift - environment always uses matching modules

**Drawbacks:**
- ❌ Cannot use different module versions per environment (unless using different branches)
- ❌ Modules cannot be easily shared across repositories

## Why We Selected Local References

### 1. Single Repository, Single Team
Our infrastructure and modules are in the **same repository** and managed by the **same team**. There's no need to version modules separately from the infrastructure code that uses them.

### 2. Branch-Based Environment Versioning
We use git branches to version entire environments:

```
CS Production:    stable/v1.0.0 branch  (code + modules frozen together)
Walmart Dev:      master branch         (latest code + modules)
```

When CS runs from `stable/v1.0.0`:
- Terraform code is from `stable/v1.0.0`
- Modules are from `stable/v1.0.0` (via `./modules/azure`)
- Everything is consistent and tested together

### 3. Simpler Mental Model
Developers don't need to think about:
- "Which module version does this environment use?"
- "Do I need to update the module ref?"
- "Did I forget to run `terraform init -upgrade`?"

Instead, they just think:
- "Which branch/tag am I deploying?"
- Everything else (code + modules) comes from that branch

### 4. Easier Development Workflow
When developing a new feature that requires module changes:

**With Local Modules:**
1. Make changes to module code
2. Make changes to Terraform code
3. Test locally with `terraform plan`
4. Commit and push to branch
5. Deploy from branch

**With Git-Based Modules:**
1. Make changes to module code
2. Commit module changes
3. Create new module version tag
4. Update Terraform code to reference new module version
5. Commit Terraform code changes
6. Run `terraform init -upgrade`
7. Test with `terraform plan`
8. Deploy

### 5. No Authentication Overhead
Git-based module sources require authentication:
- Azure DevOps PAT tokens (expire, need rotation)
- SSH keys (need to be configured on agents)
- Service principal authentication

Local modules just work - no additional authentication needed.

### 6. Consistency Guarantee
With local modules, it's **impossible** for an environment to use mismatched code and module versions. The git checkout ensures everything matches the selected branch/tag.

With git-based modules, it's **possible** (though unlikely with good practices) to have:
- Terraform code from `v2.0.0`
- Module A from `v1.5.0`
- Module B from `v2.1.0`

## How Versioning Works with Local Modules

### The Git Checkout Logic

From `pipelines/multi-env-pipeline.yml:150-167`:

```yaml
# Checkout specific git reference (branch/tag) or use current branch
- bash: |
    USE_CURRENT="${{ parameters.useCurrentBranch }}"

    if [ "$USE_CURRENT" = "True" ]; then
      CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
      echo "✅ Using current branch: $CURRENT_BRANCH"
    else
      GIT_REF="${{ parameters.gitRef }}"
      echo "Checking out specified ref: $GIT_REF"
      git fetch origin "$GIT_REF"
      git checkout "$GIT_REF"  # ← Changes ALL files to match branch/tag
      echo "✅ Checked out: $GIT_REF"
    fi

    git log -1 --oneline
  displayName: 'Checkout Version'
```

### What Happens During Deployment

1. **Pipeline starts** - Checks out the repository
2. **Git checkout runs** - Changes working directory to match the selected branch/tag
3. **All files change** including:
   - `terraform/*.tf` (Terraform code)
   - `terraform/modules/azure/*` (Module code)
   - `terraform/environments/em_bofa/*.tfvars` (Variable files)
4. **Terraform init runs** - Initializes with local modules
5. **Terraform plan/apply runs** - Uses modules from the checked-out version

### Example: CS Production Deployment

When deploying CS from `stable/v1.0.0`:

```bash
# Pipeline checks out stable/v1.0.0
git checkout stable/v1.0.0

# Now the filesystem contains:
# - Terraform code from stable/v1.0.0
# - Modules from stable/v1.0.0
# - Everything from stable/v1.0.0

# Terraform reads:
module "spoke_vnet" {
  source = "./modules/azure"  # ← Points to modules/azure from stable/v1.0.0
}

# Result: Consistent, tested version of code + modules
```

## Version Control Strategy

### Production Environments (CS)
- Use stable branches: `stable/v1.0.0`
- Created from tested, validated code
- Frozen - no changes except critical bug fixes (cherry-picked)
- Both code and modules are locked together

### Development Environments (Walmart)
- Use `master` branch
- Latest features and improvements
- Both code and modules are latest versions

### Version Tags
- Tag releases: `v1.0.0`, `v1.1.0`, etc.
- Represents entire infrastructure version (code + modules together)
- Can be used for stable branches or rollbacks

## When to Use Git-Based Module Sources

Consider git-based module sources if:

1. **Multiple repositories** need to use the same modules
2. **Different teams** manage modules vs infrastructure
3. **Module reuse** across different projects/organizations
4. **Independent module versioning** is required (upgrade one module without touching others)
5. **Module marketplace** or shared library approach

For our use case (single repository, single team, environment-based versioning), local modules are the better choice.

## Migration Path (If Needed)

If we later need to switch to git-based module sources:

1. Tag all current module versions (e.g., `modules/azure/v1.0.0`)
2. Update all module sources in `main.tf`:
   ```hcl
   module "spoke_vnet" {
     source = "git::https://dev.azure.com/insight-certent/CLOUDOPS/_git/EM.NextGen-IaC//terraform/modules/azure?ref=v1.0.0"
   }
   ```
3. Run `terraform init -upgrade` to download modules
4. Update pipeline to configure authentication (PAT token)
5. Establish module versioning policy

## References

- [Terraform Module Sources Documentation](https://www.terraform.io/language/modules/sources)
- [Git Module Sources](https://www.terraform.io/language/modules/sources#generic-git-repository)
- [Module Versioning Best Practices](https://www.terraform.io/language/modules/develop/versioning)

---

**Decision:** We use local module references (`./modules/azure`) with branch-based versioning for simplicity, consistency, and ease of development.
