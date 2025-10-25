# SFTP Storage Account - Post-Deployment Lockdown

## ⚠️ IMPORTANT: Security Configuration

The SFTP storage account was deployed with `network_default_action = "Allow"` to allow Azure DevOps agent to create containers during initial deployment.

**This is a TEMPORARY configuration for deployment only!**

---

## 🔒 Step 1: Lock Down Network Access (REQUIRED)

After successful deployment, immediately update to secure configuration:

### Update `terraform/main.tf` Line 161:

**Change FROM:**
```hcl
network_default_action = "Allow"  # Temporarily Allow for initial setup
```

**Change TO:**
```hcl
network_default_action = "Deny"  # Block all access by default (production config)
```

### Apply the Change:

```bash
# Commit the change
git add terraform/main.tf
git commit -m "Lock down SFTP storage account network access"
git push

# Or run in pipeline
terraform apply -var-file="environments/cs.tfvars"
```

---

## 🔐 Step 2: Verify Secure Configuration

After applying, verify the storage account is locked down:

```bash
# Check network rules
az storage account show \
  --name us1bofacssftpng \
  --resource-group US1-BOFA-CS-SFTP \
  --query "networkRuleSet.defaultAction" \
  --output tsv

# Expected output: Deny
```

---

## ✅ Step 3: Test VPN Access

Verify SFTP access still works for VPN users:

```bash
# Connect to VPN first
# Then test SFTP connection
sftp testuser.us1bofacssftpng@us1bofacssftpng.blob.core.windows.net
```

---

## 📋 Secure Configuration Summary

After lockdown, the storage account will have:

| Setting | Value | Impact |
|---------|-------|--------|
| **Public Access** | ❌ Disabled | No public endpoint |
| **Network Default Action** | 🔒 Deny | Block all by default |
| **Allowed Subnets** | SFTP-SUBNET only | Internal Azure access |
| **Allowed IPs** | None (empty) | No external IPs |
| **Private Endpoint** | ✅ Enabled | VPN users can access |

**Result**: Only VPN users and Azure VNet resources can access. Secure. ✅

---

## 🚨 Why This Matters

**With `network_default_action = "Allow"`**:
- ❌ Anyone can try to access the storage account (if they know the name)
- ❌ Only SFTP authentication protects it
- ❌ Vulnerable to brute force, scanning, DDoS
- ❌ **NOT compliant with security policies**

**With `network_default_action = "Deny"`**:
- ✅ Network-level protection (firewall)
- ✅ Only whitelisted IPs/subnets can reach it
- ✅ Even with stolen credentials, attacker can't connect
- ✅ **Compliant with zero-trust security model**

---

## 🔄 Alternative: Use Service Endpoint for ADO Agent

Instead of "Allow all" during deployment, you could:

1. **Create ADO agent in Azure VNet**
2. **Use self-hosted agent** in ADO-SUBNET
3. **Agent has network access** via service endpoint
4. **Deploy with `network_default_action = "Deny"`** from the start

This is more secure but requires setup. For now, the two-step approach (Allow → Deploy → Deny) is acceptable if done immediately.

---

## ⏰ Timeline

| Step | When | Status |
|------|------|--------|
| Deploy with `Allow` | Initial deployment | ✅ Done |
| **Lock down to `Deny`** | **Immediately after** | ⚠️ **PENDING** |
| Verify VPN access | After lockdown | ⬜ Not started |
| Create SFTP users | After verification | ⬜ Not started |

**ETA for lockdown**: Within 1 hour of successful deployment

---

## 📝 Checklist

- [ ] Initial deployment successful
- [ ] Containers created (uploads, downloads, archive)
- [ ] Change `network_default_action` to "Deny"
- [ ] Apply Terraform changes
- [ ] Verify storage account shows `defaultAction: Deny`
- [ ] Test VPN SFTP access
- [ ] Document NAT Gateway public IP (for partner whitelist if needed)
- [ ] Create first SFTP test user
- [ ] Delete this TODO file after completion

---

## 🔗 Related Documentation

- SFTP Playbook: `docs/SFTP-Playbook.md`
- Access Decision Matrix: `docs/SFTP-Access-Decision-Matrix.md`
- Module Updates: `SFTP-MODULE-UPDATES.md`
