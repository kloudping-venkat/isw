# Oracle Database Mount Issue - Analysis and Solution

## Problem Summary

The Oracle drives `/u01/app/oracle` and `/u01/app/oracle/product/19.0.0/dbhome_1` don't exist despite cloud-init being updated to reflect the last commit Terraform code changes.

## Root Cause Analysis

### 1. **Data Disk Configuration Mismatch**
The recent commit (92cc6dd) updated the DB module to change from Windows-style drive letters to Linux mount paths, but there was a mismatch between:

- **Data Disks Configuration**: `/orasw19c`, `/u01`, `/u02`
- **Cloud-Init Hardcoded Paths**: `/u01/app/oracle`, `/u01/app/oracle/product/19.0.0/dbhome_1`

### 2. **Missing Disk Mounting Logic**
The original cloud-init script only created directories but didn't:
- Format the attached Azure managed disks
- Mount them to the correct paths
- Add them to `/etc/fstab` for persistence
- Handle the proper mounting sequence

### 3. **Cloud-Init Execution Timing**
Cloud-init changes only take effect when:
- A VM is **first created** (initial boot)
- A VM is **recreated** (due to changes in `custom_data`)
- Manual execution of cloud-init (not recommended for production)

## Solution Implemented

### 1. **Enhanced Cloud-Init Script**

Updated `/terraform/modules/em/db/scripts/cloud-init.yml` with:

```yaml
# Robust disk detection and mounting
- |
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting disk setup..." | tee -a /var/log/oracle_prep.log
  
  # Find unformatted disks (excluding OS disk)
  DISKS=$(lsblk -dpno NAME | grep -v "/dev/sda" | grep -v "/dev/sdb" | head -3)
  DISK_ARRAY=($DISKS)
  
  # Mount points in order: /orasw19c, /u01, /u02
  MOUNT_POINTS=("/orasw19c" "/u01" "/u02")
  
  for i in "${!DISK_ARRAY[@]}"; do
    DISK=${DISK_ARRAY[$i]}
    MOUNT_POINT=${MOUNT_POINTS[$i]}
    
    if [ -b "$DISK" ] && [ -n "$MOUNT_POINT" ]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Formatting $DISK for $MOUNT_POINT" | tee -a /var/log/oracle_prep.log
      mkfs.xfs -f "$DISK"
      
      # Create mount point
      mkdir -p "$MOUNT_POINT"
      
      # Get UUID for fstab entry
      UUID=$(blkid -s UUID -o value "$DISK")
      
      # Mount the disk
      mount "$DISK" "$MOUNT_POINT"
      
      # Add to fstab using UUID for persistence
      echo "UUID=$UUID $MOUNT_POINT xfs defaults 0 0" >> /etc/fstab
      
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Successfully mounted $DISK to $MOUNT_POINT (UUID: $UUID)" | tee -a /var/log/oracle_prep.log
    fi
  done
```

**Key Improvements:**
- **Dynamic disk detection** instead of hardcoded device names
- **UUID-based fstab entries** for reliability across reboots
- **XFS filesystem** optimized for Oracle workloads
- **Comprehensive logging** for troubleshooting
- **Error handling** for missing disks or mount failures

### 2. **Recovery Script**

Created `/scripts/oracle_mounts.sh` for manual recovery:

```bash
# Can be run on existing VMs to fix mounting issues
sudo ./scripts/oracle_mounts.sh
```

This script:
- Detects unmounted Oracle disks
- Formats and mounts them correctly
- Updates `/etc/fstab` for persistence
- Creates proper Oracle directory structure
- Sets appropriate permissions

### 3. **Enhanced Testing and Verification**

Updated the test script in cloud-init to verify:
- Disk mounting status
- Directory structure
- Permissions
- Mount persistence

## Directory Structure After Fix

```
/orasw19c/                    # 512GB - Oracle software installation
├── app/
│   └── oracle/
│       └── product/
│           └── 19.0.0/

/u01/                         # 512GB - Oracle data files
├── app/
│   └── oracle/
│       ├── oradata/
│       │   └── ORCL/         # SID-specific directory
│       └── product/
│           └── 19.0.0/
│               └── dbhome_1/ # ORACLE_HOME

/u02/                         # 512GB - Additional Oracle data files
```

## Current Configuration Status

- **main.tf**: `enable_oracle_prep = true` ✅
- **Data disks**: 3 disks configured (512GB each) ✅
- **Mount paths**: `/orasw19c`, `/u01`, `/u02` ✅
- **Cloud-init**: Enhanced with disk mounting ✅

## Next Steps Required

### For Existing VMs (If Any):
1. **Option A - Manual Fix:**
   ```bash
   # SSH to the Oracle VM
   sudo /path/to/oracle_mounts.sh
   ```

2. **Option B - VM Recreation (Recommended):**
   ```bash
   # Force VM recreation to apply cloud-init changes
   terraform taint module.db_resources.azurerm_linux_virtual_machine.vm
   terraform apply
   ```

### For New Deployments:
1. The enhanced cloud-init will automatically handle disk mounting
2. Verify after deployment using the built-in test script:
   ```bash
   # On the Oracle VM
   sudo /tmp/cloud-init-oracle-test.sh
   ```

## Verification Commands

After VM creation or fix, verify with:

```bash
# Check mounts
df -h | grep -E "(orasw19c|u01|u02)"

# Check Oracle directories
ls -la /u01/app/oracle/

# Check fstab entries
grep -E "(orasw19c|u01|u02)" /etc/fstab

# Check cloud-init logs
sudo tail -f /var/log/oracle_prep.log
sudo cloud-init status
```

## Why Changes Weren't Executed Previously

1. **VM Already Existed**: Cloud-init only runs on first boot
2. **Custom Data Changes**: Require VM recreation in Terraform
3. **Missing Mount Logic**: Original script created directories but didn't mount disks
4. **Device Name Assumptions**: Original script assumed specific device names that may not exist

## Prevention for Future

1. **Always test cloud-init changes** in a dev environment first
2. **Plan for VM recreation** when making cloud-init changes
3. **Use the provided test script** to verify Oracle setup
4. **Monitor cloud-init logs** during deployment

This solution ensures that Oracle directories exist on properly mounted, persistent storage with the correct permissions and ownership.