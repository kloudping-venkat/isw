# ✅ IMPORTANT: Import Workflow Best Practice

## Correct Import Workflow

### Step 1: Import Resources
- Set `customImportList` to your resource list
- Set `action` to `plan-and-apply`
- Run pipeline → Resources get imported

### Step 2: Subsequent Runs ⚠️ **IMPORTANT**
- Set `customImportList` to `""` (empty)
- Set `action` to `plan-and-apply` 
- Run pipeline → Normal terraform apply

## Why Clear the Import List?

### Problem if NOT Cleared:
- Pipeline tries to import the same resources again
- Gets "resource already exists in state" warnings
- Adds unnecessary time to pipeline runs
- Clutters logs with import attempts

### Solution:
- **One-time import**: Use the import list once
- **Clear after import**: Set to empty string for all future runs
- **Clean pipeline**: Only imports when actually needed

## Pipeline Enhancement Suggestion

Let me add a warning message to make this clearer in the pipeline...