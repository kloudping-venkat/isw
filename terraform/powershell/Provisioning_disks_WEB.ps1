# 1. Change DVD drive letter if it's using E:
$dvd = Get-WmiObject Win32_Volume | Where-Object { $_.DriveType -eq 5 -and $_.DriveLetter -eq "E:" }
if ($dvd) {
    Set-WmiInstance -InputObject $dvd -Arguments @{DriveLetter="X:"}
    Write-Host "Changed DVD drive letter from E: to X:"
    Start-Sleep -Seconds 2
}

# Define target sizes in GB and corresponding drive letters
$diskMap = @{
    128 = 'F'
    50  = 'R'
}

# Enhanced debugging information
Write-Host "=== DISK PROVISIONING DEBUG INFORMATION ===" -ForegroundColor Cyan
Write-Host "Available disks on this system:" -ForegroundColor White
Get-Disk | ForEach-Object {
    $sizeGB = [math]::Round($_.Size/1GB, 2)
    Write-Host "  Disk $($_.Number): $sizeGB GB, Status: $($_.OperationalStatus), Partition Style: $($_.PartitionStyle)" -ForegroundColor White
}

Write-Host "`nLooking for RAW (uninitialized) disks:" -ForegroundColor White
$rawDisks = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' }
if ($rawDisks) {
    $rawDisks | ForEach-Object {
        $sizeGB = [math]::Round($_.Size/1GB, 2)
        Write-Host "  RAW Disk $($_.Number): $sizeGB GB" -ForegroundColor Green
    }
} else {
    Write-Host "  No RAW disks found!" -ForegroundColor Red
    Write-Host "  Checking all disks for existing partitions:" -ForegroundColor Yellow
    Get-Disk | ForEach-Object {
        $sizeGB = [math]::Round($_.Size/1GB, 2)
        Write-Host "    Disk $($_.Number): $sizeGB GB, Partitions: $($_.NumberOfPartitions)" -ForegroundColor Yellow
    }
}

Write-Host "`nChecking existing drive letters:" -ForegroundColor White
Get-Volume | Where-Object { $_.DriveLetter -ne $null } | Sort-Object DriveLetter | ForEach-Object {
    Write-Host "  Drive $($_.DriveLetter): $($_.FileSystemLabel) ($([math]::Round($_.Size/1GB, 2)) GB)" -ForegroundColor White
}

foreach ($sizeGB in $diskMap.Keys) {
    $driveLetter = $diskMap[$sizeGB]
    Write-Host "`nProcessing disk for drive ${driveLetter}: (${sizeGB} GB)" -ForegroundColor Yellow
    
    # Check if drive letter already exists
    $existingVolume = Get-Volume -DriveLetter $driveLetter -ErrorAction SilentlyContinue
    if ($existingVolume) {
        Write-Host "  WARNING: Drive $driveLetter already exists with label '$($existingVolume.FileSystemLabel)'" -ForegroundColor Yellow
        Write-Host "  Skipping initialization for $sizeGB GB disk" -ForegroundColor Yellow
        continue
    }
    
    # More flexible disk size matching - allow for Azure disk size variations (up to 3GB difference)
    $disk = Get-Disk | Where-Object {
        $_.PartitionStyle -eq 'RAW' -and
        [math]::Abs([math]::Round($_.Size/1GB) - $sizeGB) -le 3
    } | Sort-Object Size | Select-Object -First 1

    if ($null -eq $disk) {
        Write-Host "  No uninitialized disk found with size approximately $sizeGB GB." -ForegroundColor Red
        Write-Host "  Trying to find ANY unused disk that might match..." -ForegroundColor Yellow
        
        # Try to find any disk that's close in size, regardless of partition style
        $alternateDisk = Get-Disk | Where-Object {
            [math]::Abs([math]::Round($_.Size/1GB) - $sizeGB) -le 3 -and
            $_.NumberOfPartitions -eq 0
        } | Sort-Object Size | Select-Object -First 1
        
        if ($alternateDisk) {
            Write-Host "  Found alternate disk $($alternateDisk.Number) with $([math]::Round($alternateDisk.Size/1GB)) GB" -ForegroundColor Yellow
            $disk = $alternateDisk
        } else {
            Write-Host "  ERROR: Cannot find any suitable disk for $sizeGB GB" -ForegroundColor Red
            continue
        }
    }

    try {
        Write-Host "  Initializing Disk $($disk.Number) ($([math]::Round($disk.Size/1GB)) GB)..." -ForegroundColor Green
        Initialize-Disk -Number $disk.Number -PartitionStyle GPT -Confirm:$false
        
        Write-Host "  Creating partition on Disk $($disk.Number)..." -ForegroundColor Green
        $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter
        
        Write-Host "  Formatting partition as NTFS..." -ForegroundColor Green
        Format-Volume -Partition $partition -FileSystem NTFS -NewFileSystemLabel "Data$driveLetter" -Confirm:$false -Force
        
        Write-Host "  Assigning drive letter $driveLetter..." -ForegroundColor Green
        Set-Partition -DriveLetter $partition.DriveLetter -NewDriveLetter $driveLetter
        
        Write-Host "  SUCCESS: Disk $($disk.Number) ($([math]::Round($disk.Size/1GB)) GB) initialized and assigned to ${driveLetter}:" -ForegroundColor Green
        
        # Verify the drive is accessible
        if (Test-Path "${driveLetter}:\") {
            Write-Host "  VERIFIED: Drive ${driveLetter}: is accessible" -ForegroundColor Green
        } else {
            Write-Host "  WARNING: Drive ${driveLetter}: may not be immediately accessible" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "  ERROR: Failed to initialize disk $($disk.Number): $($_.Exception.Message)" -ForegroundColor Red
        continue
    }
}

Write-Host "`n=== FINAL DRIVE STATUS ===" -ForegroundColor Cyan
Get-Volume | Where-Object { $_.DriveLetter -ne $null } | Sort-Object DriveLetter | ForEach-Object {
    Write-Host "Drive $($_.DriveLetter): $($_.FileSystemLabel) ($([math]::Round($_.Size/1GB, 2)) GB)" -ForegroundColor White
}