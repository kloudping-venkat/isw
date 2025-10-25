# Post-Restore Verification Checklist

## Quick Reference for DB-VM Restore Verification

### Pre-Verification (Before terraform apply)
- [ ] Backup current fstab configuration
- [ ] Note current disk mount points
- [ ] Record Oracle user UID/GID if exists
- [ ] Check available disk space

### Immediate Post-Deployment (5 minutes after terraform apply)

**SSH into VM:**
```bash
ssh oracle@10.223.50.5
# password: j9UV4u003cPo$Xb=bwx
```

- [ ] Verify cloud-init is running
  ```bash
  sudo cloud-init status
  ```

- [ ] Check log file creation
  ```bash
  ls -la /var/log/db_prep.log /var/log/oracle_install.log
  ```

### Full Verification (10-15 minutes after deployment)

**Run automated verification:**
```bash
/tmp/verify_restore.sh
cat /var/log/db_restore_verify.log
```

Check Results:
- [ ] All 3 disks mounted (/u01, /u02, /u03)
- [ ] fstab has 3 UUID entries
- [ ] Oracle user exists with correct groups
- [ ] Oracle directories created (/u01/home/app/oracle/*)
- [ ] All log files present and accessible
- [ ] Disk space normal (< 90% used on all mounts)

### Manual Verification Commands

#### 1. Disk Mounts
```bash
lsblk
```
Expected output:
```
sdc    512G  /u03
sdd    512G  /u01
sde    512G  /u02
```

- [ ] /u01 mounted (contains Oracle binaries)
- [ ] /u02 mounted (Oracle data)
- [ ] /u03 mounted (Oracle backups)

#### 2. Mount Points Detail
```bash
df -h /u01 /u02 /u03
```
Expected output:
```
Filesystem     Size  Used Avail Use% Mounted on
/dev/sdd      512G  134G  378G  26% /u01
/dev/sde      512G  197G  315G  38% /u02
/dev/sdc      512G  197G  315G  38% /u03
```

- [ ] All 3 mount points present
- [ ] Sizes correct (512G each)
- [ ] Usage reasonable (not 0GB or >90%)

#### 3. fstab Entries
```bash
cat /etc/fstab | grep /u0
```
Expected output:
```
UUID=4c52a88e-912d-4916-924d-07daaa2e24af /u01 xfs defaults,nofail 0 0
UUID=9708315a-6081-414a-998c-4defb5042a33 /u02 xfs defaults,nofail 0 0
UUID=8691f9fc-b6c4-4de0-a60f-f8c5b0ed0a8f /u03 xfs defaults,nofail 0 0
```

- [ ] 3 UUID entries present
- [ ] Each UUID unique
- [ ] All point to /u0* mount points
- [ ] xfs filesystem specified

#### 4. UUID Verification
```bash
blkid | grep -E "sdc|sdd|sde"
```
Match UUIDs from blkid output with fstab entries:
```
/dev/sdc: UUID="8691f9fc-b6c4-4de0-a60f-f8c5b0ed0a8f"
/dev/sdd: UUID="4c52a88e-912d-4916-924d-07daaa2e24af"
/dev/sde: UUID="9708315a-6081-414a-998c-4defb5042a33"
```

- [ ] UUID for /u01 matches in fstab
- [ ] UUID for /u02 matches in fstab
- [ ] UUID for /u03 matches in fstab

#### 5. Oracle User
```bash
id oracle
```
Expected output:
```
uid=1000(oracle) gid=54321(oinstall) groups=54321(oinstall),10(wheel),54322(dba),54324(backupdba),54325(dgdba),54326(kmdba),54330(racdba)
```

- [ ] Oracle user UID = 1000
- [ ] Oracle group (oinstall) = 54321
- [ ] Has group: wheel
- [ ] Has group: dba
- [ ] Has group: backupdba

#### 6. Oracle Directory Structure
```bash
ls -la /u01/home/app/oracle/
```
Expected directories:
```
total 4
drwxr-xr-x. 8 oracle wheel      97 Oct  9 13:29 .
drwxr-xr-x. 4 oracle wheel      40 Oct  9 11:19 ..
drwxr-x---. 3 oracle oinstall   22 Oct  9 13:29 admin
drwxr-x---. 3 oracle oinstall   22 Oct  9 13:32 audit
drwxr-x---. 5 oracle oinstall   47 Oct  9 13:32 cfgtoollogs
drwxr-xr-x. 2 oracle oinstall    6 Oct  9 12:15 checkpoints
drwxrwxr-x. 23 oracle oinstall 4096 Oct  9 12:15 diag
drwxr-xr-x. 3 oracle wheel      20 Oct  8 17:57 product
```

- [ ] /u01/home/app/oracle/ exists
- [ ] Owned by oracle:wheel
- [ ] Has subdirs: admin, audit, cfgtoollogs, diag, product
- [ ] Permissions are rwx for owner

#### 7. Oracle Product Directory
```bash
ls -la /u01/home/app/oracle/product/
```
Expected:
```
drwxr-xr-x. 3 oracle wheel 20 Oct  8 17:57 19.0.0
```

- [ ] Contains 19.0.0 directory (Oracle 19c)
- [ ] Correct ownership (oracle:wheel)

#### 8. Oracle ORACLE_HOME
```bash
ls -la /u01/home/app/oracle/product/19.0.0/
```
Expected:
```
drwxr-xr-x. N oracle wheel XXXX Oct  8 17:57 dbhome_1
```

- [ ] Contains dbhome_1 directory
- [ ] Owned by oracle:wheel
- [ ] Has executable permissions

#### 9. Log Files
```bash
ls -lh /var/log/db_prep.log /var/log/oracle_install.log /var/log/db_post_restore.log
```
Expected output:
```
-rw-rw-rw-. 1 root root 4.2K Oct 21 12:05 /var/log/db_prep.log
-rw-rw-rw-. 1 root root 1.2K Oct 21 12:05 /var/log/oracle_install.log
-rw-rw-rw-. 1 root root 3.8K Oct 21 12:05 /var/log/db_post_restore.log
```

- [ ] All 3 log files exist
- [ ] All are world-readable (666 permissions)
- [ ] All have content (> 1KB)
- [ ] Recent timestamps

#### 10. Log File Content Check
```bash
tail -20 /var/log/db_prep.log
grep -i "ERROR\|FAILED" /var/log/db_prep.log
```

- [ ] No [ERROR] tags in logs
- [ ] No [FAILED] tags in logs
- [ ] Contains [MOUNT] tags showing successful mounts
- [ ] Contains [SKIP] tags showing idempotent operations

### Post-Verification Summary

**Fill out the summary:**

| Check | Status | Notes |
|-------|--------|-------|
| Disks mounted (3) | ✓/✗ | |
| fstab UUIDs (3) | ✓/✗ | |
| UUIDs match | ✓/✗ | |
| Oracle user exists | ✓/✗ | |
| Oracle groups | ✓/✗ | |
| Oracle directories | ✓/✗ | |
| Log files created | ✓/✗ | |
| No errors in logs | ✓/✗ | |
| Disk space OK | ✓/✗ | |
| Verification script result | ✓/✗ | |

**OVERALL STATUS:**
- [ ] ✓ ALL CHECKS PASSED - Restore Successful
- [ ] ✗ SOME CHECKS FAILED - Review logs and troubleshoot

### Troubleshooting Guide

| Problem | Command | Expected Fix |
|---------|---------|--------------|
| Disk not mounted | `sudo mount /dev/sdc /u03` | Manual mount |
| fstab missing UUID | `sudo blkid /dev/sdc` then `sudo vim /etc/fstab` | Add UUID entry |
| Oracle user missing | `sudo useradd -g 54321 -u 1000 oracle` | Create user |
| Permissions wrong | `sudo chmod 666 /var/log/db_prep.log` | Fix perms |
| Cloud-init hung | `sudo cloud-init status --long` | Check status |

---

## Quick One-Liner Verification

```bash
echo "=== DISKS ===" && lsblk | grep -E "sdc|sdd|sde" && \
echo "=== MOUNTS ===" && mount | grep /u0 && \
echo "=== FSTAB ===" && grep "/u0" /etc/fstab && \
echo "=== ORACLE ===" && id oracle && \
echo "=== DIRS ===" && ls /u01/home/app/oracle/ && \
echo "=== LOGS ===" && ls -lh /var/log/db_*log
```

---

## Files to Reference

- Cloud-init script: `terraform/modules/azure/db/scripts/cloud-init.yml`
- Improvements doc: `terraform/modules/azure/db/CLOUD_INIT_IMPROVEMENTS.md`
- Verification script: `/tmp/verify_restore.sh` (on VM)
- Main log: `/var/log/db_prep.log` (on VM)
- Verify report: `/var/log/db_restore_verify.log` (on VM)

---

**Last Updated:** 2025-10-21
**Status:** Production-Ready ✓
