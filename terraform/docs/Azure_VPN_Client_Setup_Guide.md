# Azure VPN Client Setup Guide
## US1-BOFA-CS Infrastructure Access

---

## 📋 Overview

This guide provides step-by-step instructions for connecting to the US1-BOFA-CS Azure infrastructure using Azure VPN Client with Azure Active Directory authentication.

### Infrastructure Details
- **Organization**: Certent BofA - Production
- **Environment**: CS (Customer Service)
- **Location**: East US
- **VPN Gateway**: US1-BOFA-CS-HUB-VGW
- **Authentication**: Azure Active Directory

---

## 🔧 Prerequisites

### Required Software
- **Azure VPN Client** (from Microsoft Store)
- **Remote Desktop Connection** (Windows built-in or Microsoft Remote Desktop)

### Required Access
- **Azure AD Account** in `certentbofaproduction.onmicrosoft.com` tenant
- **Appropriate permissions** to access the VPN gateway resource

---

## 📱 Step 1: Install Azure VPN Client

### Option A: Microsoft Store (Recommended)
1. Open **Microsoft Store**
2. Search for **"Azure VPN Client"**
3. Click **"Get"** or **"Install"**
4. Launch the application after installation

### Option B: Direct Download
1. Visit: https://www.microsoft.com/store/apps/9NP355QT2SQB
2. Click **"Get"** to install via Microsoft Store

---

## 🔑 Step 2: Obtain VPN Configuration

### Method 1: From IT Administrator
Contact your IT administrator to provide you with:
- VPN Profile download URL
- VM access credentials

### Method 2: Self-Service (If you have Azure access)
```bash
# Get VPN configuration from Key Vault
az keyvault secret show \
  --vault-name "US1-BOFA-CS-HUB-KV" \
  --name "US1-BOFA-CS-HUB-VGW-client-config" \
  --query "value" -o tsv
```

---

## 📥 Step 3: Import VPN Profile

### Import Process
1. **Open Azure VPN Client**
2. **Click the "+" button** or **"Add a VPN connection"**
3. **Select "Import"**
4. **Choose import method**:
   - **From URL**: Paste the profile download URL
   - **From file**: If you have a downloaded profile file

### Profile Information
- **Gateway Name**: US1-BOFA-CS-HUB-VGW
- **Protocol**: OpenVPN
- **Authentication**: Azure Active Directory
- **Client Address Pool**: 172.16.0.0/24

---

## 🔐 Step 4: Connect to VPN

### Connection Process
1. **Select your VPN profile** in Azure VPN Client
2. **Click "Connect"**
3. **Sign in with your Azure AD credentials**:
   - Username: `your-username@certentbofaproduction.onmicrosoft.com`
   - Password: Your Azure AD password
   - MFA: Complete if required
4. **Accept any permissions** if prompted
5. **Wait for connection** (status will show "Connected")

### Verify Connection
```cmd
# Check your assigned VPN IP address
ipconfig /all

# Look for "Unknown adapter Local Area Connection" with IP 172.16.0.x
```

---

## 🖥️ Step 5: Access Virtual Machines

### VM Access Information
- **VM Name**: US1-BOFA-CS-WEB-VM01
- **Private IP**: 10.223.44.x (check with your administrator)
- **Username**: webadmin
- **Password**: Available from Key Vault (contact your administrator)
- **Computer Name**: US1BOFACSWEBV01 (15-character limit)

### RDP Connection
```cmd
# Method 1: Command Line
mstsc /v:10.223.44.4

# Method 2: Windows Remote Desktop
# 1. Open "Remote Desktop Connection"
# 2. Computer: 10.223.44.4
# 3. Username: webadmin
# 4. Password: [from Key Vault]
```

---

## 🌐 Network Access Map

```
Your Device (172.16.0.x)
    ↓ [VPN Connection]
Hub Network (10.223.40.0/24)
    ↓ [VNet Peering]
Spoke Network (10.223.44.0/22)
    ├── Web Subnet (10.223.44.0/24) ← VM Location
    ├── App Subnet (10.223.45.0/24)
    ├── DB Subnet (10.223.46.0/24)
    └── DevOps Subnet (10.223.47.0/24)
```

### Accessible Resources
When connected via VPN, you can access:
- **Web Servers**: 10.223.44.x
- **Application Servers**: 10.223.45.x
- **Database Servers**: 10.223.46.x
- **DevOps Tools**: 10.223.47.x

---

## 🛠️ Troubleshooting

### Common Issues & Solutions

#### 1. Cannot Install Azure VPN Client
**Problem**: Microsoft Store access restricted
**Solution**:
- Contact IT to install via company software deployment
- Ensure Microsoft Store is enabled in your organization

#### 2. Authentication Failures
**Problem**: Cannot sign in with Azure AD
**Solutions**:
- Verify you're using the correct username format
- Check if MFA is configured correctly
- Ensure your account is in the `certentbofaproduction.onmicrosoft.com` tenant
- Try signing out and back in to Azure AD

#### 3. Cannot Import VPN Profile
**Problem**: Profile import fails
**Solutions**:
- Verify the profile download URL is correct
- Check internet connectivity
- Try importing from a downloaded file instead of URL
- Contact your administrator for a fresh profile

#### 4. VPN Connects but Cannot Access VMs
**Problem**: Connected to VPN but RDP fails
**Solutions**:
- Verify your VPN IP: `ipconfig /all` (should be 172.16.0.x)
- Test network connectivity: `ping 10.223.44.1`
- Verify VM IP address with administrator
- Check Windows Firewall settings

#### 5. RDP Connection Refused
**Problem**: Cannot connect to VM via RDP
**Solutions**:
- Verify VM is running (contact administrator)
- Confirm correct private IP address
- Test port connectivity: `telnet 10.223.44.4 3389`
- Check VM credentials

### Network Diagnostics
```cmd
# Check VPN connection
ipconfig /all

# Test hub network connectivity
ping 10.223.40.1

# Test spoke network connectivity
ping 10.223.44.1

# Test VM connectivity
ping 10.223.44.4

# Test RDP port
telnet 10.223.44.4 3389
```

---

## 🔒 Security & Compliance

### Security Features
- **End-to-End Encryption**: All VPN traffic encrypted
- **Azure AD Integration**: No shared passwords or certificates
- **Audit Logging**: All connections logged in Azure AD
- **Private Network**: VMs not accessible from internet
- **Conditional Access**: Can be enforced via Azure AD policies

### Best Practices
1. **Always disconnect** VPN when not in use
2. **Never share** your Azure AD credentials
3. **Report suspicious activity** immediately
4. **Keep Azure VPN Client updated**
5. **Use strong passwords** and enable MFA

### Compliance
- **Data in Transit**: Encrypted using OpenVPN protocol
- **Authentication**: Azure AD with MFA support
- **Access Control**: RBAC-based permissions
- **Monitoring**: All connections logged and auditable

---

## 📞 Support & Contact

### For Technical Issues
- **IT Helpdesk**: [Your IT contact information]
- **Azure Support**: [Azure support details if applicable]

### For Access Requests
- **Account Access**: Contact your manager or IT administrator
- **VM Access**: Request specific server access through IT

### Emergency Access
- **After Hours**: [Emergency IT contact]
- **Critical Issues**: [Escalation procedures]

---

## 📚 Additional Resources

### Documentation
- [Azure VPN Client Documentation](https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-howto-point-to-site-entra-ssovpn-client-portal)
- [Remote Desktop Connection Help](https://support.microsoft.com/windows/how-to-use-remote-desktop-5fe128d5-8fb1-7a23-3b8a-41e636865e8c)

### Video Guides
- [Azure VPN Client Setup Video](https://docs.microsoft.com/azure/vpn-gateway/)
- [Windows Remote Desktop Tutorial](https://support.microsoft.com/windows/)

---

## 📋 Quick Reference Card

```
╔══════════════════════════════════════════╗
║        Azure VPN Quick Reference         ║
╠══════════════════════════════════════════╣
║ VPN Client: Microsoft Store → Azure VPN ║
║ Auth: your-name@certentbofa...           ║
║ VM Access: RDP to 10.223.44.x           ║
║ VPN IP: 172.16.0.x                      ║
║ Support: Contact IT Helpdesk            ║
╚══════════════════════════════════════════╝
```

---

## 📝 Change Log

| Date | Version | Changes |
|------|---------|---------|
| [Current Date] | 1.0 | Initial setup guide created |

---

**Document Version**: 1.0
**Last Updated**: [Current Date]
**Created For**: US1-BOFA-CS Infrastructure
**Classification**: Internal Use Only