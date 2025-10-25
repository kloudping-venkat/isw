# Module Versioning Strategy

## Overview

To protect CS environment from Walmart changes, we use a versioning strategy:

## Approach: Environment-Based Branching

### Branch Strategy

```
master                    # Latest development
  ├── stable/cs-v1.0.0   # CS production (frozen)
  ├── stable/cs-v1.1.0   # Future CS updates
  └── feature/walmart     # Walmart development
```

### Current Versions

| Environment | Version | Branch/Tag | Status |
|-------------|---------|------------|--------|
| CS          | v1.0.0  | stable/cs-v1.0.0 | Production |
| Walmart     | dev     | master | Development |

## Deployment Strategy

### For CS (Production)
- Uses: `stable/cs-v1.0.0` branch
- Changes: Only critical fixes
- Updates: Create new stable branch (v1.1.0)

### For Walmart (Development)
- Uses: `master` branch
- Changes: Active development
- Updates: Continuous

## How It Works

### CS Pipeline
```yaml
# Uses stable branch
- checkout: self
  ref: stable/cs-v1.0.0
```

### Walmart Pipeline
```yaml
# Uses master branch
- checkout: self
  ref: master
```

## Alternative: Module Git Source

If you want to completely separate module versions:

```hcl
# CS uses v1.0.0 tag
module "hub_infrastructure" {
  source = "git::https://github.com/your-org/EM.NextGen-IaC.git//terraform/modules/azure?ref=v1.0.0"
  ...
}

# Walmart uses master
module "hub_infrastructure" {
  source = "git::https://github.com/your-org/EM.NextGen-IaC.git//terraform/modules/azure?ref=master"
  ...
}
```

## Recommended Approach for Your Case

**Use separate pipeline branches:**

1. **CS Pipeline**: Points to `stable/cs-v1.0.0`
2. **Walmart Pipeline**: Points to `master`

This way:
- ✅ CS is protected (frozen at v1.0.0)
- ✅ Walmart can evolve independently
- ✅ Easy to merge Walmart changes back to CS when ready
- ✅ No complex module source changes needed

## Migration Plan

### Phase 1: Protect CS
1. Merge walmart branch to master
2. Create stable/cs-v1.0.0 branch
3. Tag as v1.0.0
4. Update CS pipeline to use stable branch

### Phase 2: Develop Walmart
1. Continue development on master
2. Test Walmart thoroughly
3. When stable, merge to stable/walmart-v1.0.0

### Phase 3: Sync Back to CS (Future)
1. Cherry-pick improvements from master
2. Test in CS dev environment
3. Create stable/cs-v1.1.0
4. Update CS pipeline

## Best Practice

**Never change stable/* branches directly**
- Stable branches are immutable
- Create new stable branch for updates
- Update pipeline refs to new version

**Use master for active development**
- All new features go to master
- Test thoroughly before creating stable branch
- Stable branches are snapshots of master
