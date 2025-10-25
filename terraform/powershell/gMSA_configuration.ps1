# gMSA Account Configuration Script for BOFA Environment
# Creates and configures group Managed Service Account

param(
    [string]$Environment = "Prod",  # Prod/Dev environment
    [string]$ServiceAccountName = "svc-emapp-gmsa",
    [string]$DNSHostName = $null,
    [string[]]$PrincipalsAllowedToRetrieveManagedPassword = @()
)

Write-Host "Starting gMSA Account Configuration for $Environment environment..." -ForegroundColor Cyan

# Define environment-specific settings
switch ($Environment.ToLower()) {
    "prod" {
        $DomainName = "CertentEMBOFA.Prod"
        $OUPath = "OU=ServiceAccounts,OU=AADDC Computers,DC=CertentEMBOFA,DC=Prod"
        $DefaultPrincipals = @("CertentEMBOFA.Prod\BOFAProd_DevOps", "CertentEMBOFA.Prod\BOFAProd_AppServers")
    }
    "dev" {
        $DomainName = "CertentEMBOFA.Dev"
        $OUPath = "OU=ServiceAccounts,OU=AADDC Computers,DC=CertentEMBOFA,DC=Dev"
        $DefaultPrincipals = @("CertentEMBOFA.Dev\BOFADev_DevOps", "CertentEMBOFA.Dev\BOFADev_AppServers")
    }
    default {
        Write-Error "Invalid environment: $Environment. Must be 'Prod' or 'Dev'"
        exit 1
    }
}

# Use provided principals or defaults
if ($PrincipalsAllowedToRetrieveManagedPassword.Count -eq 0) {
    $PrincipalsAllowedToRetrieveManagedPassword = $DefaultPrincipals
}

try {
    # Import Active Directory module
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Host "Active Directory module imported successfully." -ForegroundColor Green

    # Check if gMSA already exists
    $existingGMSA = Get-ADServiceAccount -Filter "Name -eq '$ServiceAccountName'" -ErrorAction SilentlyContinue

    if ($existingGMSA) {
        Write-Host "gMSA account '$ServiceAccountName' already exists." -ForegroundColor Yellow

        # Update the gMSA configuration
        Write-Host "Updating gMSA account configuration..." -ForegroundColor Cyan
        Set-ADServiceAccount -Identity $ServiceAccountName -PrincipalsAllowedToRetrieveManagedPassword $PrincipalsAllowedToRetrieveManagedPassword
        Write-Host "gMSA account updated successfully." -ForegroundColor Green
    }
    else {
        # Create new gMSA account
        Write-Host "Creating new gMSA account '$ServiceAccountName'..." -ForegroundColor Cyan

        $gmsaParams = @{
            Name = $ServiceAccountName
            DNSHostName = if ($DNSHostName) { $DNSHostName } else { "$ServiceAccountName.$DomainName" }
            PrincipalsAllowedToRetrieveManagedPassword = $PrincipalsAllowedToRetrieveManagedPassword
            Path = $OUPath
            Enabled = $true
        }

        New-ADServiceAccount @gmsaParams
        Write-Host "gMSA account '$ServiceAccountName' created successfully." -ForegroundColor Green
    }

    # Install the gMSA on local computer
    Write-Host "Installing gMSA account on local computer..." -ForegroundColor Cyan
    Install-ADServiceAccount -Identity $ServiceAccountName
    Write-Host "gMSA account installed on local computer." -ForegroundColor Green

    # Test the gMSA installation
    Write-Host "Testing gMSA account installation..." -ForegroundColor Cyan
    $testResult = Test-ADServiceAccount -Identity $ServiceAccountName

    if ($testResult) {
        Write-Host "gMSA account test successful." -ForegroundColor Green
    } else {
        Write-Warning "gMSA account test failed. Please verify configuration."
    }

    # Add gMSA to local administrators (if needed for service operation)
    Write-Host "Adding gMSA to local administrators..." -ForegroundColor Cyan
    try {
        $gmsaAccount = "$DomainName\$ServiceAccountName$"
        Add-LocalGroupMember -Group "Administrators" -Member $gmsaAccount
        Write-Host "Successfully added gMSA to local administrators." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to add gMSA to local administrators: $_"
        Write-Host "Note: This may be required depending on service requirements." -ForegroundColor Yellow
    }

    # Display configuration summary
    Write-Host "`n=== gMSA Configuration Summary ===" -ForegroundColor Cyan
    Write-Host "Service Account Name: $ServiceAccountName" -ForegroundColor White
    Write-Host "Domain: $DomainName" -ForegroundColor White
    Write-Host "DNS Host Name: $($gmsaParams.DNSHostName)" -ForegroundColor White
    Write-Host "Organizational Unit: $OUPath" -ForegroundColor White
    Write-Host "Principals Allowed to Retrieve Password:" -ForegroundColor White
    foreach ($principal in $PrincipalsAllowedToRetrieveManagedPassword) {
        Write-Host "  - $principal" -ForegroundColor White
    }
    Write-Host "=================================" -ForegroundColor Cyan

} catch {
    Write-Error "Failed to configure gMSA account: $_"
    Write-Host "Common issues:" -ForegroundColor Yellow
    Write-Host "1. Computer must be domain-joined" -ForegroundColor Yellow
    Write-Host "2. Active Directory PowerShell module must be available" -ForegroundColor Yellow
    Write-Host "3. User must have permissions to create service accounts" -ForegroundColor Yellow
    Write-Host "4. Domain functional level must support gMSA" -ForegroundColor Yellow
    exit 1
}

Write-Host "gMSA configuration completed successfully!" -ForegroundColor Green