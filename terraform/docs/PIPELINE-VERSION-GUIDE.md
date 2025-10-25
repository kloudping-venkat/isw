# Pipeline Version Selection Guide

## How to Use the Multi-Env Pipeline with Versions

### Pipeline Parameters

When you run the `multi-env-pipeline`, you'll now see:

```
Product/Client:     em_bofa
Environment:        cs | walmart | dev | prod
Version:            master | stable/cs-v1.0.0 | v1.0.0
Terraform Action:   plan-only | plan-and-apply
```

## Recommended Settings

### For CS Production

**Use stable version** to prevent changes:

```
Product/Client:     em_bofa
Environment:        cs
Version:            stable/cs-v1.0.0  ⚠️ IMPORTANT!
Terraform Action:   plan-only (first), then plan-and-apply
```

**Why?**
- ✅ CS is frozen at working v1.0.0
- ✅ Walmart changes won't affect CS
- ✅ Safe and predictable

### For Walmart Development

**Use master** for active development:

```
Product/Client:     em_bofa
Environment:        walmart
Version:            master  ✅
Terraform Action:   plan-only (first), then plan-and-apply
```

**Why?**
- ✅ Latest features and fixes
- ✅ Active development
- ✅ Independent from CS

### For Testing/Development

```
Product/Client:     em_bofa
Environment:        dev
Version:            master
Terraform Action:   plan-only
```

## Version Reference

| Version | Description | Use Case |
|---------|-------------|----------|
| `master` | Latest development | Walmart, testing, new features |
| `stable/cs-v1.0.0` | CS Production baseline | CS production deployments |
| `v1.0.0` | Tag for v1.0.0 | Same as stable/cs-v1.0.0 |
| `stable/walmart-v1.0.0` | Walmart stable (future) | When Walmart goes to production |

## What Happens When You Select a Version?

### Pipeline Behavior

The pipeline will:
1. **Checkout** the selected branch/tag
2. **Use** the terraform code from that version
3. **Deploy** resources based on that version

### Example: CS with v1.0.0

```yaml
# Pipeline checks out stable/cs-v1.0.0
- checkout: self
  ref: stable/cs-v1.0.0

# Uses modules from v1.0.0
modules/azure/...      # v1.0.0 code
terraform/main.tf      # v1.0.0 configuration
```

### Example: Walmart with master

```yaml
# Pipeline checks out master
- checkout: self
  ref: master

# Uses latest modules
modules/azure/...      # Latest code
terraform/main.tf      # Latest configuration
```

## Common Scenarios

### Scenario 1: Deploy CS (Normal Operation)

1. Run pipeline
2. Select:
   - Environment: `cs`
   - Version: `stable/cs-v1.0.0`
   - Action: `plan-only`
3. Review plan (should show 0 changes)
4. If changes appear, investigate why!
5. Only apply if changes are expected

### Scenario 2: Deploy Walmart (Development)

1. Run pipeline
2. Select:
   - Environment: `walmart`
   - Version: `master`
   - Action: `plan-only`
3. Review plan
4. If good, run again with `plan-and-apply`

### Scenario 3: Test CS Update

Before creating a new stable version:

1. Run pipeline
2. Select:
   - Environment: `cs`
   - Version: `master` (test latest code)
   - Action: `plan-only`
3. Review what would change
4. Test in dev environment first
5. If safe, create new stable version

### Scenario 4: Hotfix for CS

If CS needs urgent fix:

```bash
# 1. Create hotfix branch from stable
git checkout stable/cs-v1.0.0
git checkout -b hotfix/cs-critical-fix

# 2. Make fix, test, commit

# 3. Create new stable version
git checkout -b stable/cs-v1.0.1
git tag -a v1.0.1 -m "CS Hotfix"
git push origin stable/cs-v1.0.1
git push origin v1.0.1
```

Then update pipeline parameter values to include `stable/cs-v1.0.1`

## Protection Strategy

### CS is Protected

- **Always use**: `stable/cs-v1.0.0`
- **Never use**: `master` (unless testing)
- **Updates**: Only via new stable versions

### Walmart is Active

- **Always use**: `master`
- **Updates**: Continuous
- **Stable version**: Create when ready for production

## Troubleshooting

### "Plan shows unexpected changes for CS"

**Check:**
1. Are you using `stable/cs-v1.0.0`?
2. Or accidentally using `master`?

**Fix:**
- Always select `stable/cs-v1.0.0` for CS production

### "Walmart plan fails"

**Check:**
1. Are you using `master`?
2. Did you commit latest changes?

**Fix:**
- Ensure latest code is in master
- Check tfstate container exists

### "Wrong version deployed"

**Check:**
- What version was selected in pipeline run?
- Check pipeline logs for "Checkout" step

**Fix:**
- Always verify version parameter before running

## Best Practices

1. ✅ **CS**: Always use `stable/cs-v1.0.0`
2. ✅ **Walmart**: Use `master` during development
3. ✅ **Test first**: Always run `plan-only` before `plan-and-apply`
4. ✅ **Verify version**: Check pipeline logs for correct checkout
5. ✅ **Document changes**: Note which version was used in deployments

## Future: When Walmart Goes Production

When Walmart is ready for production:

```bash
# Create stable version for Walmart
git checkout master
git checkout -b stable/walmart-v1.0.0
git tag -a walmart-v1.0.0 -m "Walmart Production v1.0.0"
git push origin stable/walmart-v1.0.0
git push origin walmart-v1.0.0
```

Then use:
```
Environment: walmart
Version: stable/walmart-v1.0.0
```

---

**Remember**: Version selection protects your environments! 🛡️
