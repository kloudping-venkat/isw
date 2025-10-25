# Versioning Implementation Plan

## Goal
Protect CS environment from Walmart changes by versioning the codebase.

## Step-by-Step Implementation

### Step 1: Merge Walmart Branch to Master

```bash
# Ensure you're on the walmart branch with all commits
git checkout isw-301-walmart
git status  # Make sure everything is committed

# Switch to master and merge
git checkout master
git pull origin master
git merge isw-301-walmart

# Resolve any conflicts if they exist
# Then push to master
git push origin master
```

### Step 2: Create Stable Branch for CS

```bash
# Create stable branch for CS from master
git checkout master
git checkout -b stable/cs-v1.0.0

# Push the stable branch
git push origin stable/cs-v1.0.0
```

### Step 3: Tag the Release

```bash
# Create annotated tag
git tag -a v1.0.0 -m "Release v1.0.0 - CS Production Baseline

Stable release for CS environment:
- Hub-spoke architecture with shared hub capability
- CS environment fully deployed and tested
- State migration completed (all resources at [0] paths)
- Flag-based module enablement
- Multi-environment pipeline support

Modules included:
- modules/azure (networking, compute, keyvault, etc.)
- modules/azure/db (Oracle database)
- modules/azure/sftp (SFTP with private endpoints)

Environments supported:
- CS (Customer Service) - Production
- Walmart - In development

Protected for CS production use."

# Push the tag
git push origin v1.0.0
```

### Step 4: Update CS Pipeline to Use Stable Branch

Edit: `pipelines/cs-azure-pipeline.yml` (or create new cs-specific pipeline)

```yaml
trigger:
  branches:
    include:
      - stable/cs-v*  # Only trigger on stable CS versions

resources:
  repositories:
    - repository: self
      type: git
      ref: stable/cs-v1.0.0  # Pin to v1.0.0

# ... rest of pipeline
```

### Step 5: Keep Master for Walmart Development

Master branch remains active for Walmart:
- Walmart pipeline uses `master` branch
- All Walmart changes go to `master`
- CS remains on `stable/cs-v1.0.0`

### Step 6: Future Updates

**For CS Updates (Critical Fixes)**:
```bash
# Create hotfix branch from stable
git checkout stable/cs-v1.0.0
git checkout -b hotfix/cs-critical-fix

# Make changes, test, commit

# Merge back to stable and create new version
git checkout stable/cs-v1.0.0
git merge hotfix/cs-critical-fix
git push origin stable/cs-v1.0.0

# Or create new stable version
git checkout -b stable/cs-v1.0.1
git push origin stable/cs-v1.0.1
git tag -a v1.0.1 -m "CS Hotfix"
git push origin v1.0.1
```

**For Walmart Updates**:
```bash
# Work on master
git checkout master
# Make changes, test, commit
git push origin master
```

## Alternative: Separate Pipelines

### Option A: Branch-Based Separation (Recommended)

**CS Pipeline** (`pipelines/cs-pipeline.yml`):
```yaml
trigger:
  branches:
    include:
      - stable/cs-v*

pool: 'terraform-agents'

steps:
  - checkout: self
    ref: refs/heads/stable/cs-v1.0.0  # Always use v1.0.0

  - template: templates/init.yml
    parameters:
      environment: cs

  # ... rest of CS deployment
```

**Walmart Pipeline** (`pipelines/walmart-pipeline.yml`):
```yaml
trigger:
  branches:
    include:
      - master
      - feature/walmart-*

pool: 'terraform-agents'

steps:
  - checkout: self
    ref: refs/heads/master  # Use latest master

  - template: templates/init.yml
    parameters:
      environment: walmart

  # ... rest of Walmart deployment
```

### Option B: Keep Multi-Env Pipeline with Ref Override

Update `multi-env-pipeline.yml`:

```yaml
parameters:
  - name: environment
    type: string

  # Add branch/ref parameter
  - name: gitRef
    displayName: 'Git Branch/Tag'
    type: string
    default: 'master'
    values:
      - master
      - stable/cs-v1.0.0
      - stable/cs-v1.1.0

steps:
  - checkout: self
    ref: ${{ parameters.gitRef }}

  # Set ref based on environment
  - ${{ if eq(parameters.environment, 'cs') }}:
    - checkout: self
      ref: stable/cs-v1.0.0

  - ${{ else }}:
    - checkout: self
      ref: master
```

## Recommendation

**Use Option A (Separate Pipelines):**

1. ✅ **Clear separation** - CS pipeline is independent
2. ✅ **Safe** - CS can't accidentally use wrong version
3. ✅ **Simple** - Easy to understand and maintain
4. ✅ **Flexible** - Each environment can evolve independently

## Implementation Checklist

- [ ] Merge isw-301-walmart to master
- [ ] Create stable/cs-v1.0.0 branch
- [ ] Tag as v1.0.0
- [ ] Create cs-specific pipeline (or update multi-env)
- [ ] Test CS deployment from stable branch
- [ ] Test Walmart deployment from master
- [ ] Document version in README
- [ ] Update team on versioning strategy

## Rollback Plan

If something goes wrong:

```bash
# CS can always use the tag
git checkout v1.0.0

# Or revert to stable branch
git checkout stable/cs-v1.0.0
```

## Summary

| Environment | Branch | Tag | Pipeline | Changes |
|-------------|--------|-----|----------|---------|
| CS Production | stable/cs-v1.0.0 | v1.0.0 | cs-pipeline.yml | Frozen |
| Walmart Dev | master | - | walmart-pipeline.yml | Active |

This keeps CS safe while allowing Walmart to evolve! 🎯
