# Disk Attachment Verification Script
# Verifies that Azure data disks are properly attached before disk provisioning
Write-Host "=== AZURE DISK ATTACHMENT VERIFICATION ===" -ForegroundColor Cyan

# Function to wait for disks to be recognized
function Wait-ForDiskRecognition {
    param(
        [int]$ExpectedDiskCount,
        [int]$MaxWaitSeconds = 120
    )
    
    $waitTime = 0
    $intervalSeconds = 10
    
    while ($waitTime -lt $MaxWaitSeconds) {
        $allDisks = Get-Disk
        $totalDisks = $allDisks.Count
        
        Write-Host "Current disk count: $totalDisks (waiting for at least $ExpectedDiskCount total disks)" -ForegroundColor White
        
        if ($totalDisks -ge $ExpectedDiskCount) {
            Write-Host "SUCCESS: All expected disks are now visible to the OS" -ForegroundColor Green
            return $true
        }
        
        Write-Host "Waiting ${intervalSeconds} seconds for additional disks to be recognized..." -ForegroundColor Yellow
        Start-Sleep -Seconds $intervalSeconds
        $waitTime += $intervalSeconds
    }
    
    Write-Host "WARNING: Timeout waiting for all disks to be recognized" -ForegroundColor Yellow
    return $false
}

# Expected configuration based on VM role
$vmName = $env:COMPUTERNAME
Write-Host "VM Name: $vmName" -ForegroundColor White

# Determine expected disk configuration based on VM name pattern
$expectedDataDisks = 0
$diskConfig = @()

if ($vmName -like "*-WEB-*") {
    $expectedDataDisks = 2
    $diskConfig = @(
        @{ Size = 128; DriveLetter = 'F'; Description = "Web server data disk" },
        @{ Size = 50; DriveLetter = 'R'; Description = "Web server logs disk" }
    )
    Write-Host "Detected WEB server - expecting 2 data disks (128GB, 50GB)" -ForegroundColor White
}
elseif ($vmName -like "*-APP-*") {
    $expectedDataDisks = 2
    $diskConfig = @(
        @{ Size = 128; DriveLetter = 'E'; Description = "App server data disk" },
        @{ Size = 50; DriveLetter = 'R'; Description = "App server logs disk" }
    )
    Write-Host "Detected APP server - expecting 2 data disks (128GB, 50GB)" -ForegroundColor White
}
elseif ($vmName -like "*-ADO-*") {
    $expectedDataDisks = 2
    $diskConfig = @(
        @{ Size = 128; DriveLetter = 'E'; Description = "ADO agent data disk" },
        @{ Size = 128; DriveLetter = 'R'; Description = "ADO agent temp disk" }
    )
    Write-Host "Detected ADO server - expecting 2 data disks (128GB, 128GB)" -ForegroundColor White
}
else {
    Write-Host "Unknown VM type - using generic verification" -ForegroundColor Yellow
    $expectedDataDisks = 2
}

# Total expected disks = OS disk (1) + data disks
$expectedTotalDisks = 1 + $expectedDataDisks
Write-Host "Expected total disks: $expectedTotalDisks (1 OS + $expectedDataDisks data)" -ForegroundColor White

# Wait for disk recognition
Write-Host "`nWaiting for Azure data disks to be recognized by Windows..." -ForegroundColor Yellow
$diskRecognitionSuccess = Wait-ForDiskRecognition -ExpectedDiskCount $expectedTotalDisks

# Display current disk status
Write-Host "`n=== CURRENT DISK STATUS ===" -ForegroundColor Cyan
$allDisks = Get-Disk | Sort-Object Number
foreach ($disk in $allDisks) {
    $sizeGB = [math]::Round($disk.Size/1GB, 2)
    $status = $disk.OperationalStatus
    $partitionStyle = $disk.PartitionStyle
    $isBootDisk = if ($disk.IsBoot) { " (BOOT DISK)" } else { "" }
    
    Write-Host "Disk $($disk.Number): $sizeGB GB - $status - $partitionStyle$isBootDisk" -ForegroundColor White
    
    if ($partitionStyle -eq "RAW") {
        Write-Host "  → Available for initialization" -ForegroundColor Green
    } elseif ($disk.NumberOfPartitions -gt 0) {
        Write-Host "  → Already partitioned ($($disk.NumberOfPartitions) partition(s))" -ForegroundColor Yellow
    }
}

# Verify specific disk sizes match expectations
Write-Host "`n=== DISK SIZE VERIFICATION ===" -ForegroundColor Cyan
$rawDisks = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' -and -not $_.IsBoot } | Sort-Object Size
Write-Host "Found $($rawDisks.Count) uninitialized non-boot disks" -ForegroundColor White

foreach ($config in $diskConfig) {
    $expectedSize = $config.Size
    $driveLetter = $config.DriveLetter
    $description = $config.Description
    
    $matchingDisk = $rawDisks | Where-Object {
        [math]::Abs([math]::Round($_.Size/1GB) - $expectedSize) -le 3
    } | Select-Object -First 1
    
    if ($matchingDisk) {
        $actualSize = [math]::Round($matchingDisk.Size/1GB, 2)
        Write-Host "✓ Found disk for ${driveLetter}: - Disk $($matchingDisk.Number) ($actualSize GB) - $description" -ForegroundColor Green
    } else {
        Write-Host "✗ Missing disk for ${driveLetter}: ($expectedSize GB) - $description" -ForegroundColor Red
        $recommendedAction = "Check Azure portal to verify data disk attachment"
        Write-Host "  Recommendation: $recommendedAction" -ForegroundColor Yellow
    }
}

# Final status
$rawDiskCount = $rawDisks.Count
if ($rawDiskCount -ge $expectedDataDisks) {
    Write-Host "`n✓ VERIFICATION PASSED: All expected data disks are available for provisioning" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n✗ VERIFICATION FAILED: Expected $expectedDataDisks data disks, found $rawDiskCount" -ForegroundColor Red
    Write-Host "This may cause disk provisioning scripts to fail" -ForegroundColor Red
    Write-Host "`nTroubleshooting steps:" -ForegroundColor Yellow
    Write-Host "1. Check Azure portal for VM data disk attachment status" -ForegroundColor Yellow
    Write-Host "2. Verify Terraform data disk configuration" -ForegroundColor Yellow
    Write-Host "3. Try running 'Get-Disk' manually to refresh disk list" -ForegroundColor Yellow
    Write-Host "4. Check Windows Event Logs for disk attachment errors" -ForegroundColor Yellow
    exit 1
}