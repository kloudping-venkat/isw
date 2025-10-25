# Storage Connectivity Test Script
# Tests connectivity to Azure Storage Account from VM
param(
    [string]$StorageAccountName,
    [string]$ContainerName = "powershell-scripts"
)

$ErrorActionPreference = "Continue"

Write-Host "=== AZURE STORAGE CONNECTIVITY TEST ===" -ForegroundColor Cyan
Write-Host "Storage Account: $StorageAccountName" -ForegroundColor White
Write-Host "Container: $ContainerName" -ForegroundColor White
Write-Host "Test Time: $(Get-Date)" -ForegroundColor White

# Test 1: DNS Resolution
Write-Host "`n1. Testing DNS Resolution..." -ForegroundColor Yellow
$storageUrl = "$StorageAccountName.blob.core.windows.net"
try {
    $dnsResult = Resolve-DnsName -Name $storageUrl -ErrorAction Stop
    Write-Host "✓ DNS Resolution successful: $($dnsResult[0].IPAddress)" -ForegroundColor Green
} catch {
    Write-Host "✗ DNS Resolution failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "This indicates DNS connectivity issues" -ForegroundColor Yellow
}

# Test 2: Basic Connectivity (ping)
Write-Host "`n2. Testing Basic Connectivity..." -ForegroundColor Yellow
try {
    $pingResult = Test-NetConnection -ComputerName $storageUrl -Port 443 -ErrorAction Stop
    if ($pingResult.TcpTestSucceeded) {
        Write-Host "✓ TCP 443 connection successful" -ForegroundColor Green
    } else {
        Write-Host "✗ TCP 443 connection failed" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Connectivity test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: HTTP/HTTPS Access
Write-Host "`n3. Testing HTTP Access to Container..." -ForegroundColor Yellow
$containerUrl = "https://$storageUrl/$ContainerName"
try {
    $webRequest = Invoke-WebRequest -Uri $containerUrl -Method HEAD -TimeoutSec 30 -ErrorAction Stop
    Write-Host "✓ HTTP access successful (Status: $($webRequest.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "✗ HTTP access failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Yellow
}

# Test 4: Sample File Download
Write-Host "`n4. Testing Sample File Download..." -ForegroundColor Yellow
$testFileUrl = "https://$storageUrl/$ContainerName/BOFA_Master_Deploy.ps1"
try {
    $downloadTest = Invoke-WebRequest -Uri $testFileUrl -Method HEAD -TimeoutSec 30 -ErrorAction Stop
    Write-Host "✓ Sample file accessible (Status: $($downloadTest.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "✗ Sample file download failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Yellow
    }
}

# Test 5: Network Configuration
Write-Host "`n5. Network Configuration..." -ForegroundColor Yellow
try {
    $networkConfig = Get-NetIPConfiguration | Where-Object { $_.NetAdapter.Status -eq "Up" }
    foreach ($config in $networkConfig) {
        Write-Host "Interface: $($config.InterfaceAlias)" -ForegroundColor White
        Write-Host "  IP Address: $($config.IPv4Address.IPAddress)" -ForegroundColor White
        Write-Host "  Default Gateway: $($config.IPv4DefaultGateway.NextHop)" -ForegroundColor White
        Write-Host "  DNS Servers: $($config.DNSServer.ServerAddresses -join ', ')" -ForegroundColor White
    }
} catch {
    Write-Host "Could not retrieve network configuration: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Test 6: Proxy Configuration
Write-Host "`n6. Proxy Configuration..." -ForegroundColor Yellow
try {
    $proxySettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction SilentlyContinue
    if ($proxySettings.ProxyEnable -eq 1) {
        Write-Host "✗ Proxy enabled: $($proxySettings.ProxyServer)" -ForegroundColor Red
        Write-Host "This may interfere with storage account access" -ForegroundColor Yellow
    } else {
        Write-Host "✓ No proxy configured" -ForegroundColor Green
    }
} catch {
    Write-Host "Could not check proxy settings: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n=== CONNECTIVITY TEST COMPLETED ===" -ForegroundColor Cyan

# Return appropriate exit code
# This script is for diagnostics only, so always return 0
exit 0