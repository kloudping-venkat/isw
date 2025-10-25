# Oracle Client Installation Script
# Downloads and installs Oracle Client for Windows from BOFA environment

param(
    [string]$OracleVersion = "19.3.0.0.0",
    [string]$InstallPath = "C:\Oracle\client_19_3",
    [string]$DownloadUrl = "https://usngdevenvaddons.blob.core.windows.net/quarter1/Oracle_Install_WINDOWS.X64_193000_client.zip?sp=r&st=2025-08-07T20:13:29Z&se=2026-08-08T04:28:29Z&spr=https&sv=2024-11-04&sr=b&sig=%2B7iurY8GcEOvqcZMf3VHhDnP%2Fhxzr88X3XrzF7hWSSY%3D"
)

$stagingDir = "C:\TEMP\Oracle"
$tempPath = "$env:TEMP\oracle_install"

Write-Host "Starting Oracle Client Installation..." -ForegroundColor Cyan
Write-Host "Oracle Version: $OracleVersion" -ForegroundColor White
Write-Host "Installation Path: $InstallPath" -ForegroundColor White

try {
    # Create staging and temp directories
    Write-Host "Creating directories..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
    New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null

    # Download Oracle Client from BOFA environment
    Write-Host "Downloading Oracle Client from BOFA environment..." -ForegroundColor Cyan
    $oracleZip = "$tempPath\Oracle_Install_Windows.zip"
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $oracleZip
        Write-Host "Oracle Client downloaded successfully from BOFA environment." -ForegroundColor Green
    } catch {
        Write-Error "Failed to download Oracle Client from BOFA environment: $_"
        throw "Oracle Client download failed"
    }

    # Extract Oracle Client
    Write-Host "Extracting Oracle Client..." -ForegroundColor Cyan
    Expand-Archive -Path $oracleZip -DestinationPath $tempPath -Force

    # Find and process the Oracle client installation files
    $extractedContents = Get-ChildItem -Path $tempPath -Recurse
    Write-Host "Extracted contents:" -ForegroundColor Yellow
    $extractedContents | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor Gray }

    # Check if this is a full Oracle client installer
    $setupExe = Get-ChildItem -Path $tempPath -Filter "setup.exe" -Recurse | Select-Object -First 1
    if ($setupExe) {
        Write-Host "Found Oracle installer. Running silent installation..." -ForegroundColor Cyan

        # Run Oracle installer in silent mode
        $installArgs = @(
            "-silent",
            "-nowait",
            "-ignoreSysPrereqs",
            "ORACLE_HOME=$InstallPath",
            "ORACLE_BASE=C:\Oracle",
            "oracle.install.client.installType=Runtime"
        )

        Start-Process -FilePath $setupExe.FullName -ArgumentList $installArgs -Wait -NoNewWindow
        Write-Host "Oracle Client installation completed." -ForegroundColor Green
    } else {
        # Fallback: copy files directly if it's a zip package
        Write-Host "No installer found. Copying Oracle Client files..." -ForegroundColor Cyan
        $oracleDir = Get-ChildItem -Path $tempPath -Directory | Select-Object -First 1
        if ($oracleDir) {
            Copy-Item -Path "$($oracleDir.FullName)\*" -Destination $InstallPath -Recurse -Force
            Write-Host "Oracle Client files copied to $InstallPath" -ForegroundColor Green
        } else {
            # Copy all files to installation directory
            Copy-Item -Path "$tempPath\*" -Destination $InstallPath -Recurse -Force
            Write-Host "All Oracle files copied to $InstallPath" -ForegroundColor Green
        }
    }

    # Set environment variables
    Write-Host "Configuring environment variables..." -ForegroundColor Cyan

    # Add Oracle Client to PATH
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    if ($currentPath -notlike "*$InstallPath*") {
        $newPath = $currentPath + ";$InstallPath"
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
        Write-Host "Added Oracle Client to system PATH." -ForegroundColor Green
    }

    # Set ORACLE_HOME
    [Environment]::SetEnvironmentVariable("ORACLE_HOME", $InstallPath, "Machine")
    Write-Host "Set ORACLE_HOME to $InstallPath" -ForegroundColor Green

    # Set TNS_ADMIN (for tnsnames.ora location)
    $tnsAdminPath = "$InstallPath\network\admin"
    New-Item -ItemType Directory -Path $tnsAdminPath -Force | Out-Null
    [Environment]::SetEnvironmentVariable("TNS_ADMIN", $tnsAdminPath, "Machine")
    Write-Host "Set TNS_ADMIN to $tnsAdminPath" -ForegroundColor Green

    # Create basic tnsnames.ora template
    $tnsnamesTemplate = @"
# Oracle TNS Names Configuration
# Add your Oracle database connection entries here
# Example:
# PROD_DB =
#   (DESCRIPTION =
#     (ADDRESS = (PROTOCOL = TCP)(HOST = your-oracle-server)(PORT = 1521))
#     (CONNECT_DATA =
#       (SERVER = DEDICATED)
#       (SERVICE_NAME = your-service-name)
#     )
#   )
"@

    $tnsnamesPath = "$tnsAdminPath\tnsnames.ora"
    if (-not (Test-Path $tnsnamesPath)) {
        $tnsnamesTemplate | Out-File -FilePath $tnsnamesPath -Encoding ASCII
        Write-Host "Created tnsnames.ora template at $tnsnamesPath" -ForegroundColor Green
    }

    # Install Visual C++ Redistributable if needed (Oracle Client dependency)
    Write-Host "Checking Visual C++ Redistributable..." -ForegroundColor Cyan
    $vcRedistUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    $vcRedistPath = "$tempPath\vc_redist.x64.exe"

    try {
        Invoke-WebRequest -Uri $vcRedistUrl -OutFile $vcRedistPath
        Start-Process -FilePath $vcRedistPath -ArgumentList "/quiet", "/norestart" -Wait
        Write-Host "Visual C++ Redistributable installed/updated." -ForegroundColor Green
    } catch {
        Write-Warning "Could not install Visual C++ Redistributable. Oracle Client may require it."
    }

    # Test Oracle Client installation
    Write-Host "Testing Oracle Client installation..." -ForegroundColor Cyan
    $env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine")

    try {
        $sqlplusPath = Join-Path $InstallPath "sqlplus.exe"
        if (Test-Path $sqlplusPath) {
            $testResult = & $sqlplusPath -version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Oracle Client installation verified successfully." -ForegroundColor Green
                Write-Host "SQL*Plus version information:" -ForegroundColor White
                Write-Host $testResult -ForegroundColor White
            }
        } else {
            Write-Host "Basic Oracle Client installed (SQL*Plus not available)." -ForegroundColor Yellow
        }
    } catch {
        Write-Warning "Could not verify Oracle Client installation: $_"
    }

    # Clean up temporary files
    Write-Host "Cleaning up temporary files..." -ForegroundColor Cyan
    Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue

    # Display installation summary
    Write-Host "`n=== Oracle Client Installation Summary ===" -ForegroundColor Cyan
    Write-Host "Installation Path: $InstallPath" -ForegroundColor White
    Write-Host "Oracle Version: $OracleVersion" -ForegroundColor White
    Write-Host "ORACLE_HOME: $InstallPath" -ForegroundColor White
    Write-Host "TNS_ADMIN: $tnsAdminPath" -ForegroundColor White
    Write-Host "Components Installed:" -ForegroundColor White
    Write-Host "  - Oracle Instant Client Basic: Yes" -ForegroundColor White
    Write-Host "  - SQL*Plus: $(if (Test-Path "$InstallPath\sqlplus.exe") {'Yes'} else {'No'})" -ForegroundColor White
    Write-Host "  - ODBC Driver: $(if (Test-Path "$InstallPath\sqora32.dll") {'Yes'} else {'No'})" -ForegroundColor White
    Write-Host "=========================================" -ForegroundColor Cyan

    Write-Host "Oracle Client installation completed successfully!" -ForegroundColor Green
    Write-Host "Note: You may need to restart the server for environment variables to take full effect." -ForegroundColor Yellow

} catch {
    Write-Error "Oracle Client installation failed: $_"
    Write-Host "Manual installation may be required." -ForegroundColor Red
    Write-Host "Download Oracle Instant Client from: https://www.oracle.com/database/technologies/instant-client/downloads.html" -ForegroundColor Yellow
    exit 1
}