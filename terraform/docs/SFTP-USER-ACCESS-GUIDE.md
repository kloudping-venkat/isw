# SFTP User Access Guide

## How Users Access the SFTP Server

### Architecture Overview

```
User (External/Internal)
    │
    ├─ Option 1: Via NAT Gateway Public IP (Outbound)
    │     └─> us1bofacssftpng.blob.core.windows.net (SFTP endpoint)
    │
    └─ Option 2: Via Private Endpoint (VPN Users)
          └─> 10.223.54.x (Private IP in SFTP-SUBNET)
```

## Access Methods

### 🌐 Option 1: Public Access via SFTP Endpoint (Recommended for External Users)

**SFTP Endpoint**: `us1bofacssftpng.blob.core.windows.net`

**Connection String**:
```bash
sftp <username>.us1bofacssftpng@us1bofacssftpng.blob.core.windows.net
```

**How it works**:
1. User connects to Azure's public SFTP endpoint
2. Azure Storage handles authentication
3. Network rules on storage account control access (currently `default_action = "Deny"`)
4. Only connections from whitelisted IPs/subnets are allowed

**Current Configuration**:
- ❌ **Public access disabled** (`public_network_access_enabled = false`)
- ✅ **Network default action**: Deny all
- ✅ **Allowed subnets**: SFTP-SUBNET only
- ⚠️ **External users CANNOT connect** (by design for security)

---

### 🔒 Option 2: Private Endpoint via VPN (Current Setup)

**Private Endpoint IP**: `10.223.54.x` (in SFTP-SUBNET)
**Private DNS**: `us1bofacssftpng.privatelink.blob.core.windows.net`

**Connection String** (for VPN users):
```bash
sftp <username>.us1bofacssftpng@us1bofacssftpng.blob.core.windows.net
```

**How it works**:
1. User connects to VPN (gets IP in `172.16.0.0/24` range)
2. DNS resolves `us1bofacssftpng.blob.core.windows.net` to private endpoint IP
3. Traffic routes through Hub → Spoke → SFTP-SUBNET
4. Private endpoint forwards to storage account

**Current Configuration**:
- ✅ **Private endpoint enabled**
- ✅ **Private DNS Zone linked to Spoke VNet**
- ✅ **Only accessible via VPN or from within Azure VNet**
- ✅ **Secure - no public internet exposure**

---

## 🔑 User Authentication Methods

Azure Storage SFTP supports two authentication methods:

### Method 1: SSH Password (Simple)
```bash
# Create user with password
az storage account local-user create \
  --account-name us1bofacssftpng \
  --resource-group US1-BOFA-CS-SFTP \
  --name johndoe \
  --home-directory uploads \
  --permission-scope permissions=rcwdl service=blob resource-name=uploads \
  --has-ssh-password true

# Get password (shown once)
az storage account local-user regenerate-password \
  --account-name us1bofacssftpng \
  --resource-group US1-BOFA-CS-SFTP \
  --name johndoe

# User connects:
sftp johndoe.us1bofacssftpng@us1bofacssftpng.blob.core.windows.net
Password: [enter password]
```

### Method 2: SSH Key (More Secure - Recommended)
```bash
# Generate SSH key pair (user side)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/bofa_sftp_key

# Create user with SSH key
az storage account local-user create \
  --account-name us1bofacssftpng \
  --resource-group US1-BOFA-CS-SFTP \
  --name johndoe \
  --home-directory uploads \
  --permission-scope permissions=rcwdl service=blob resource-name=uploads \
  --ssh-authorized-key key="$(cat ~/.ssh/bofa_sftp_key.pub)"

# User connects:
sftp -i ~/.ssh/bofa_sftp_key johndoe.us1bofacssftpng@us1bofacssftpng.blob.core.windows.net
```

---

## 📋 User Permission Scopes

When creating users, you define their container access:

| Permission | Description |
|------------|-------------|
| `r` | Read files |
| `c` | Create files |
| `w` | Write/modify files |
| `d` | Delete files |
| `l` | List files and directories |

**Example Permissions**:
```bash
# Read-only user (can only download)
--permission-scope permissions=rl service=blob resource-name=downloads

# Upload-only user (can only upload, not see other files)
--permission-scope permissions=cw service=blob resource-name=uploads

# Full access user (read, write, delete)
--permission-scope permissions=rcwdl service=blob resource-name=uploads \
--permission-scope permissions=rcwdl service=blob resource-name=downloads
```

---

## 🛠️ Complete User Setup Example

### Scenario: BofA Partner needs to upload files

**Requirements**:
- Partner uploads files from external network
- SSH key authentication (no passwords)
- Upload-only access (cannot see/download other files)
- Files go to `uploads` container

**Step 1: Enable Public Access** (Currently Disabled)

Update `terraform/main.tf`:
```hcl
# Network Security
public_network_access_enabled = true  # Enable for external access
network_default_action        = "Deny"
allowed_subnet_ids            = [module.spoke_vnet.subnet_ids["${local.prefix}-SPOKE-SFTP-SUBNET"]]
allowed_ip_addresses          = ["203.0.113.0/24"]  # Partner's public IP range
```

Run `terraform apply` to update storage account.

**Step 2: Create SFTP User**
```bash
# Generate SSH key (partner side)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/bofa_partner_key

# Admin creates user with partner's public key
az storage account local-user create \
  --account-name us1bofacssftpng \
  --resource-group US1-BOFA-CS-SFTP \
  --name partner-acme \
  --home-directory uploads \
  --permission-scope permissions=cw service=blob resource-name=uploads \
  --ssh-authorized-key key="ssh-rsa AAAAB3NzaC1yc2EAAAA... partner@acme.com"
```

**Step 3: Partner Connects**
```bash
# Partner uploads file
sftp -i ~/.ssh/bofa_partner_key partner-acme.us1bofacssftpng@us1bofacssftpng.blob.core.windows.net

sftp> put invoice_12345.pdf
Uploading invoice_12345.pdf to /uploads/invoice_12345.pdf
invoice_12345.pdf                    100%  1234KB   1.2MB/s   00:01

sftp> quit
```

---

## 🔐 Current Security Configuration

| Setting | Value | Impact |
|---------|-------|--------|
| **Public Network Access** | ❌ Disabled | External users CANNOT connect |
| **Network Default Action** | Deny | Block all by default |
| **Allowed Subnets** | SFTP-SUBNET only | Only internal Azure access |
| **Allowed IPs** | None (`[]`) | No external IPs whitelisted |
| **Private Endpoint** | ✅ Enabled | VPN users can access |
| **NAT Gateway Public IP** | Available | For outbound traffic only |

### To Enable External Partner Access:

1. **Update Terraform** (`main.tf`):
   ```hcl
   public_network_access_enabled = true
   allowed_ip_addresses = [
     "203.0.113.0/24",  # Partner 1 IP range
     "198.51.100.50/32" # Partner 2 specific IP
   ]
   ```

2. **Apply Changes**:
   ```bash
   terraform apply
   ```

3. **Create SFTP users** as shown above

4. **Provide connection details** to partners:
   - SFTP endpoint: `us1bofacssftpng.blob.core.windows.net`
   - Username: `<username>.us1bofacssftpng`
   - Authentication: SSH key (provide public key to admin)
   - Container: `uploads`, `downloads`, etc.

---

## 📊 Access Scenarios

### Scenario 1: Internal EM Team (VPN Access)
**Who**: CloudOps, DevOps teams
**Access Method**: VPN → Private Endpoint
**Connection**:
```bash
# Connect to VPN first
# Then SFTP via private endpoint
sftp admin.us1bofacssftpng@us1bofacssftpng.blob.core.windows.net
```

### Scenario 2: External Partner (Whitelisted IP)
**Who**: BofA partners with fixed IP addresses
**Access Method**: Direct via public SFTP endpoint
**Prerequisites**:
- Enable `public_network_access_enabled = true`
- Add partner IP to `allowed_ip_addresses`
**Connection**:
```bash
sftp partner.us1bofacssftpng@us1bofacssftpng.blob.core.windows.net
```

### Scenario 3: Azure VM/Service (Internal)
**Who**: VMs in APP-SUBNET, WEB-SUBNET, etc.
**Access Method**: Via spoke VNet routing
**Prerequisites**: Add subnets to `allowed_subnet_ids`
**Connection**:
```bash
sftp service-account.us1bofacssftpng@us1bofacssftpng.blob.core.windows.net
```

---

## 🧪 Testing SFTP Access

### Test 1: Check DNS Resolution
```bash
# From VPN-connected machine
nslookup us1bofacssftpng.blob.core.windows.net
# Should resolve to private IP (10.223.54.x)

# From external network (if public access enabled)
nslookup us1bofacssftpng.blob.core.windows.net
# Should resolve to Azure public IP
```

### Test 2: Test SFTP Connection
```bash
# Test connection (will prompt for auth)
sftp testuser.us1bofacssftpng@us1bofacssftpng.blob.core.windows.net

# With SSH key
sftp -i ~/.ssh/id_rsa testuser.us1bofacssftpng@us1bofacssftpng.blob.core.windows.net
```

### Test 3: Check Network Connectivity
```bash
# Test port 22 connectivity
telnet us1bofacssftpng.blob.core.windows.net 22

# Or using nc
nc -zv us1bofacssftpng.blob.core.windows.net 22
```

---

## 📞 Troubleshooting

### Issue: "Connection refused" or "Network unreachable"

**Cause**: Public access disabled or IP not whitelisted

**Solution**:
1. Check if `public_network_access_enabled = true` in Terraform
2. Verify your IP is in `allowed_ip_addresses` list
3. Check NSG rules allow port 22
4. If using VPN, verify VPN connection is active

### Issue: "Permission denied (publickey)"

**Cause**: SSH key not configured or wrong key used

**Solution**:
1. Verify SSH key was added to user:
   ```bash
   az storage account local-user show \
     --account-name us1bofacssftpng \
     --resource-group US1-BOFA-CS-SFTP \
     --name username
   ```
2. Check correct private key file: `sftp -i ~/.ssh/correct_key ...`
3. Verify key permissions: `chmod 600 ~/.ssh/private_key`

### Issue: "No such file or directory" when uploading

**Cause**: User doesn't have permission to target container

**Solution**:
1. Check user permissions:
   ```bash
   az storage account local-user show \
     --account-name us1bofacssftpng \
     --resource-group US1-BOFA-CS-SFTP \
     --name username
   ```
2. Update permission scopes to include the container

---

## 📝 Quick Reference

**Storage Account**: `us1bofacssftpng`
**SFTP Endpoint**: `us1bofacssftpng.blob.core.windows.net`
**Resource Group**: `US1-BOFA-CS-SFTP`
**Containers**: `uploads`, `downloads`, `archive`
**NAT Gateway Public IP**: Check outputs: `terraform output sftp_nat_gateway_public_ip`
**Private Endpoint IP**: Check outputs: `terraform output sftp_private_endpoint_ip`

**Create User Command Template**:
```bash
az storage account local-user create \
  --account-name us1bofacssftpng \
  --resource-group US1-BOFA-CS-SFTP \
  --name <username> \
  --home-directory <container> \
  --permission-scope permissions=<r|c|w|d|l> service=blob resource-name=<container> \
  --ssh-authorized-key key="<public-key-content>"
```

**List All Users**:
```bash
az storage account local-user list \
  --account-name us1bofacssftpng \
  --resource-group US1-BOFA-CS-SFTP
```

**Delete User**:
```bash
az storage account local-user delete \
  --account-name us1bofacssftpng \
  --resource-group US1-BOFA-CS-SFTP \
  --name <username>
```
