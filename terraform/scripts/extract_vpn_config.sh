#!/bin/bash

# Azure VPN Configuration Extractor
# This script extracts VPN configuration values from your deployed infrastructure

echo "============================================="
echo "Azure VPN Configuration Extractor"
echo "US1-BOFA-CS Infrastructure"
echo "============================================="

# Check if user is logged into Azure
echo "Checking Azure authentication..."
if ! az account show &> /dev/null; then
    echo "❌ Not logged into Azure. Please run 'az login' first."
    exit 1
fi

echo "✅ Azure authentication verified"
echo ""

# Get current subscription and tenant
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo "📋 Azure Account Information:"
echo "   Subscription ID: $SUBSCRIPTION_ID"
echo "   Tenant ID: $TENANT_ID"
echo ""

# Resource Group and Key Vault names
RG_HUB="US1-BOFA-CS-HUB-RG"
RG_SPOKE="US1-BOFA-CS-SPOKE-RG"
KV_HUB="us1bofacshubkv3s28lq5s"
VGW_NAME="US1-BOFA-CS-HUB-VGW"

echo "🔑 Extracting VPN Gateway Information..."

# Get VPN Gateway public IP
VGW_PIP=$(az network public-ip show \
    --resource-group "$RG_HUB" \
    --name "${VGW_NAME}-PIP" \
    --query ipAddress -o tsv 2>/dev/null)

if [ -n "$VGW_PIP" ]; then
    echo "   ✅ VPN Gateway Public IP: $VGW_PIP"
else
    echo "   ⚠️  VPN Gateway Public IP not found or still provisioning"
fi

# Get VPN client configuration from Key Vault
echo ""
echo "🗝️ Extracting VPN Configuration from Key Vault..."

VPN_CONFIG_SECRET="${VGW_NAME}-client-config"
VPN_CONFIG=$(az keyvault secret show \
    --vault-name "$KV_HUB" \
    --name "$VPN_CONFIG_SECRET" \
    --query value -o tsv 2>/dev/null)

if [ -n "$VPN_CONFIG" ]; then
    echo "   ✅ VPN configuration found in Key Vault"

    # Parse JSON configuration
    DOWNLOAD_URL=$(echo "$VPN_CONFIG" | jq -r '.vpn_client_config.download_url' 2>/dev/null)
    ADDRESS_SPACE=$(echo "$VPN_CONFIG" | jq -r '.vpn_client_config.address_space[]' 2>/dev/null)

    echo "   📥 Profile Download URL: $DOWNLOAD_URL"
    echo "   🌐 Client Address Space: $ADDRESS_SPACE"
else
    echo "   ⚠️  VPN configuration not found in Key Vault"
fi

echo ""
echo "🖥️ Extracting VM Information..."

# Get VM information
VM_NAME="US1-BOFA-CS-WEB-VM01"
VM_PRIVATE_IP=$(az vm show \
    --resource-group "$RG_SPOKE" \
    --name "$VM_NAME" \
    --show-details \
    --query privateIps -o tsv 2>/dev/null)

if [ -n "$VM_PRIVATE_IP" ]; then
    echo "   ✅ VM Name: $VM_NAME"
    echo "   🏠 VM Private IP: $VM_PRIVATE_IP"

    # Get VM admin password from Key Vault
    VM_PASSWORD_SECRET="${VM_NAME}-admin-password"
    if az keyvault secret show --vault-name "$KV_HUB" --name "$VM_PASSWORD_SECRET" &> /dev/null; then
        echo "   🔑 VM Password: Available in Key Vault secret '$VM_PASSWORD_SECRET'"
    else
        echo "   ⚠️  VM Password secret not found in Key Vault"
    fi
else
    echo "   ⚠️  VM not found or not running"
fi

echo ""
echo "🔐 Generating VPN Client Package with Certificates..."

# Generate VPN client package and get server certificate data
VPN_PACKAGE_URL=""
SERVER_CERT_HASH=""
SERVER_CERT_DATA=""

# For Azure AD authentication, we need to get the profile from Azure directly
echo "   📦 Generating Azure AD VPN client package..."

# Generate VPN client configuration URL (for Azure AD authentication)
echo "   🔗 Getting VPN client configuration download URL..."
CONFIG_URL=$(az network vnet-gateway vpn-client generate \
    --resource-group "$RG_HUB" \
    --name "$VGW_NAME" \
    --authentication-method "EAPTLS" \
    --output tsv 2>/dev/null || echo "")

if [ -n "$CONFIG_URL" ]; then
    VPN_PACKAGE_URL="$CONFIG_URL"
    echo "   ✅ VPN package URL: $VPN_PACKAGE_URL"
else
    # Try alternative REST API approach
    PACKAGE_RESPONSE=$(az rest \
        --method post \
        --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_HUB/providers/Microsoft.Network/virtualNetworkGateways/$VGW_NAME/generatevpnclientpackage?api-version=2023-06-01" \
        --body '{"authenticationMethod":"EAPTLS"}' \
        --headers "Content-Type=application/json" 2>/dev/null || echo "")

    if [ -n "$PACKAGE_RESPONSE" ]; then
        VPN_PACKAGE_URL=$(echo "$PACKAGE_RESPONSE" | tr -d '"')
        echo "   ✅ VPN package URL (via REST): $VPN_PACKAGE_URL"
    fi
fi

# Download and extract the actual Azure VPN profile
if [ -n "$VPN_PACKAGE_URL" ]; then
    echo "   📥 Downloading Azure VPN profile..."
    TEMP_DIR=$(mktemp -d)

    # Download the zip package
    curl -s "$VPN_PACKAGE_URL" -o "$TEMP_DIR/vpn_package.zip"

    if [ -f "$TEMP_DIR/vpn_package.zip" ] && [ -s "$TEMP_DIR/vpn_package.zip" ]; then
        cd "$TEMP_DIR"
        unzip -q vpn_package.zip 2>/dev/null

        # Look for the Azure VPN profile file
        AZURE_PROFILE=""
        if [ -f "AzureVPN/azurevpnconfig.xml" ]; then
            AZURE_PROFILE="AzureVPN/azurevpnconfig.xml"
        elif [ -f "azurevpnconfig.xml" ]; then
            AZURE_PROFILE="azurevpnconfig.xml"
        else
            # Find any XML file that might contain the profile
            AZURE_PROFILE=$(find . -name "*.xml" -type f | head -1)
        fi

        if [ -n "$AZURE_PROFILE" ] && [ -f "$AZURE_PROFILE" ]; then
            echo "   ✅ Found Azure VPN profile: $AZURE_PROFILE"

            # Extract certificate information from the actual Azure profile
            SERVER_CERT_HASH=$(grep -oP '(?<=<hash>)[^<]+' "$AZURE_PROFILE" 2>/dev/null | head -1)
            SERVER_CERT_DATA=$(grep -oP '(?<=<certificatedata>)[^<]+' "$AZURE_PROFILE" 2>/dev/null | head -1)

            # Also try alternative patterns
            if [ -z "$SERVER_CERT_HASH" ]; then
                SERVER_CERT_HASH=$(xmllint --xpath "//cert/hash/text()" "$AZURE_PROFILE" 2>/dev/null || echo "")
            fi
            if [ -z "$SERVER_CERT_DATA" ]; then
                SERVER_CERT_DATA=$(xmllint --xpath "//cert/certificatedata/text()" "$AZURE_PROFILE" 2>/dev/null || echo "")
            fi

            echo "   📋 Certificate hash found: ${SERVER_CERT_HASH:0:20}..."
            echo "   📋 Certificate data found: ${#SERVER_CERT_DATA} characters"
        else
            echo "   ⚠️  Azure VPN profile XML not found in package"
        fi

        cd - > /dev/null
        rm -rf "$TEMP_DIR"
    else
        echo "   ⚠️  Could not download VPN package or file is empty"
    fi
else
    echo "   ⚠️  Could not generate VPN package"
fi

# If still no certificate data, try alternative method using PowerShell-style REST call
if [ -z "$SERVER_CERT_HASH" ]; then
    echo "   🔍 Trying alternative certificate extraction..."

    # Get VPN Gateway SSL certificate directly
    GATEWAY_INFO=$(az network vnet-gateway show \
        --resource-group "$RG_HUB" \
        --name "$VGW_NAME" \
        --query "{fqdn:bgpSettings.asn, publicIp:'$(az network public-ip show --resource-group "$RG_HUB" --name "${VGW_NAME}-PIP" --query ipAddress -o tsv)'}" \
        -o json 2>/dev/null)

    # For Azure AD auth, we can use a known certificate pattern
    if [ -n "$VGW_PIP" ]; then
        # Try to get SSL certificate from the gateway IP
        SERVER_CERT_INFO=$(echo | openssl s_client -connect "$VGW_PIP:443" -servername "$VGW_PIP" 2>/dev/null | openssl x509 -fingerprint -sha256 -noout 2>/dev/null || echo "")

        if [ -n "$SERVER_CERT_INFO" ]; then
            SERVER_CERT_HASH=$(echo "$SERVER_CERT_INFO" | grep -oP '(?<=SHA256 Fingerprint=)[A-F0-9:]+' | tr -d ':' | base64 -d 2>/dev/null | base64 2>/dev/null || echo "")
        fi
    fi
fi

echo ""
echo "📄 Generating Complete Azure VPN XML Profile..."

# For Azure AD authentication, server certificate validation is optional
# If we don't have cert data, we'll create a profile that relies on Azure AD auth only
if [ -z "$SERVER_CERT_HASH" ]; then
    echo "   ℹ️  No server certificate found - using Azure AD authentication only"
    SERVER_CERT_HASH=""
    SERVER_CERT_DATA=""
fi

# Generate the complete XML profile with server certificate data
cat > "${VGW_NAME}-profile.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<AzVpnProfile>
    <any>true</any>
    <version>1</version>
    <name>$VGW_NAME</name>
    <secondaryProfileName>None</secondaryProfileName>
    <serverlist>
        <ServerEntry>
            <fqdn>$VGW_PIP</fqdn>
            <displayname>$VGW_NAME ($VGW_PIP)</displayname>
        </ServerEntry>
    </serverlist>
    <clientauth>
        <type>aad</type>
        <aad>
            <issuer>https://sts.windows.net/$TENANT_ID/</issuer>
            <tenant>https://login.microsoftonline.com/$TENANT_ID</tenant>
            <audience>41b23e61-6c1e-4545-b367-cd054e0ed4b4</audience>
            <cachesigninuser>true</cachesigninuser>
            <disableSso>true</disableSso>
            <enablegrouptoken>false</enablegrouptoken>
        </aad>
    </clientauth>
    <protocolconfig>
        <sslprotocolConfig>
            <transportprotocol>tcp</transportprotocol>
        </sslprotocolConfig>
    </protocolconfig>
    <clientconfig>
        <addresspool>$ADDRESS_SPACE</addresspool>
    </clientconfig>
    <servervalidation>
        <!-- Server certificate validation - Azure AD authentication provides additional security -->
        <serversecret>$SERVER_CERT_HASH</serversecret>
        <cert>
            <hash>$SERVER_CERT_HASH</hash>
            <ekulist></ekulist>
            <issuer>CN=Microsoft Azure VPN Gateway</issuer>
            <certificatedata>$SERVER_CERT_DATA</certificatedata>
        </cert>
    </servervalidation>
</AzVpnProfile>
EOF

echo "✅ Complete XML profile saved to '${VGW_NAME}-profile.xml'"

echo ""
echo "📄 Generating Client Configuration Summary..."

cat > vpn_client_config.txt << EOF
================================================================
Azure VPN Client Configuration Summary
================================================================

Infrastructure Details:
- Gateway Name: $VGW_NAME
- Resource Group: $RG_HUB
- Location: East US
- Subscription: $SUBSCRIPTION_ID
- Tenant: $TENANT_ID

VPN Connection:
- Gateway Public IP: $VGW_PIP
- Client Address Space: $ADDRESS_SPACE
- Authentication: Azure Active Directory
- Protocol: OpenVPN

VM Access:
- VM Name: $VM_NAME
- Private IP: $VM_PRIVATE_IP
- Username: webadmin
- Password Location: Key Vault secret '$VM_PASSWORD_SECRET'

Key Vault Access:
- Key Vault: $KV_HUB
- VPN Config Secret: $VPN_CONFIG_SECRET

Profile Files Generated:
- XML Profile: ${VGW_NAME}-profile.xml
- Package URL: $VPN_PACKAGE_URL
- Summary: vpn_client_config.txt

================================================================
Client Instructions:
1. Install Azure VPN Client from Microsoft Store
2. Import the XML profile file: ${VGW_NAME}-profile.xml
3. Connect using Azure AD credentials
4. RDP to VM using private IP: $VM_PRIVATE_IP
================================================================
EOF

echo "✅ Configuration summary saved to 'vpn_client_config.txt'"

echo ""
echo "🔍 Additional Commands for IT Administrators:"
echo ""
echo "# Get full VPN configuration:"
echo "az keyvault secret show --vault-name '$KV_HUB' --name '$VPN_CONFIG_SECRET'"
echo ""
echo "# Get VM password:"
echo "az keyvault secret show --vault-name '$KV_HUB' --name '$VM_PASSWORD_SECRET' --query value -o tsv"
echo ""
echo "# Check VPN Gateway status:"
echo "az network vnet-gateway show --resource-group '$RG_HUB' --name '$VGW_NAME' --query provisioningState"
echo ""
echo "# List all Key Vault secrets:"
echo "az keyvault secret list --vault-name '$KV_HUB' --query '[].name' -o table"

echo ""
echo "============================================="
echo "Configuration extraction completed!"
echo "============================================="