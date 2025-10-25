# Domain Join Status Check Script
# Run this script on the VM to check domain join status

Write-Host "=== Domain Join Status Check ===" -ForegroundColor Cyan
Write-Host ""

# Get computer system information
try {
    $computerInfo = Get-ComputerInfo -Property CsDomain, CsPartOfDomain, CsWorkgroup, CsDomainRole -ErrorAction Stop

    Write-Host "Computer Name: $env:COMPUTERNAME" -ForegroundColor White
    Write-Host "Current Domain: $($computerInfo.CsDomain)" -ForegroundColor White
    Write-Host "Part of Domain: $($computerInfo.CsPartOfDomain)" -ForegroundColor White
    Write-Host "Workgroup: $($computerInfo.CsWorkgroup)" -ForegroundColor White
    Write-Host "Domain Role: $($computerInfo.CsDomainRole)" -ForegroundColor White
    Write-Host ""

    if ($computerInfo.CsPartOfDomain) {
        Write-Host "✅ SUCCESS: Computer is joined to domain: $($computerInfo.CsDomain)" -ForegroundColor Green

        # Test domain controller connectivity
        Write-Host "Testing domain controller connectivity..." -ForegroundColor Yellow
        try {
            $testResult = Test-ComputerSecureChannel -Verbose
            if ($testResult) {
                Write-Host "✅ Domain trust relationship is healthy" -ForegroundColor Green
            } else {
                Write-Host "❌ Domain trust relationship failed" -ForegroundColor Red
            }
        } catch {
            Write-Host "❌ Unable to test domain trust: $($_.Exception.Message)" -ForegroundColor Red
        }

        # Check domain services
        Write-Host ""
        Write-Host "Checking domain-related services..." -ForegroundColor Yellow
        $services = @("Netlogon", "W32Time", "DNS")
        foreach ($service in $services) {
            try {
                $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
                if ($svc) {
                    $status = if ($svc.Status -eq "Running") { "✅" } else { "❌" }
                    Write-Host "$status $service`: $($svc.Status)" -ForegroundColor $(if ($svc.Status -eq "Running") { "Green" } else { "Red" })
                }
            } catch {
                Write-Host "❌ $service`: Not found or error" -ForegroundColor Red
            }
        }

        # Check DNS resolution for domain
        Write-Host ""
        Write-Host "Testing DNS resolution for domain..." -ForegroundColor Yellow
        try {
            $dnsTest = Resolve-DnsName $computerInfo.CsDomain -ErrorAction Stop
            Write-Host "✅ DNS resolution successful for $($computerInfo.CsDomain)" -ForegroundColor Green
        } catch {
            Write-Host "❌ DNS resolution failed for $($computerInfo.CsDomain): $($_.Exception.Message)" -ForegroundColor Red
        }

    } else {
        Write-Host "❌ WARNING: Computer is NOT joined to a domain" -ForegroundColor Red
        Write-Host "Current workgroup: $($computerInfo.CsWorkgroup)" -ForegroundColor Yellow

        # Check if domain join logs exist
        Write-Host ""
        Write-Host "Checking for domain join attempts..." -ForegroundColor Yellow
        $logFiles = @(
            "C:\temp\domain_join_status.txt",
            "C:\temp\bofa_restart_marker.txt",
            "C:\temp\bofa_config_complete.txt"
        )

        foreach ($logFile in $logFiles) {
            if (Test-Path $logFile) {
                $content = Get-Content $logFile -Raw
                Write-Host "📄 Found log: $logFile" -ForegroundColor Cyan
                Write-Host "   Content: $content" -ForegroundColor White
            }
        }
    }

} catch {
    Write-Host "❌ Error getting computer information: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Additional Troubleshooting Commands ===" -ForegroundColor Cyan
Write-Host "If domain join failed, you can try:" -ForegroundColor Yellow
Write-Host "1. Check network connectivity to domain controllers (10.223.26.68, 10.223.26.69)" -ForegroundColor White
Write-Host "   Test-NetConnection 10.223.26.68 -Port 389" -ForegroundColor Gray
Write-Host "2. Check DNS configuration:" -ForegroundColor White
Write-Host "   Get-DnsClientServerAddress" -ForegroundColor Gray
Write-Host "3. Manually join domain:" -ForegroundColor White
Write-Host "   Add-Computer -DomainName 'your.domain.local' -Credential (Get-Credential) -Restart" -ForegroundColor Gray
Write-Host "4. Check event logs:" -ForegroundColor White
Write-Host "   Get-WinEvent -FilterHashtable @{LogName='System'; ID=12,13,14} -MaxEvents 10" -ForegroundColor Gray