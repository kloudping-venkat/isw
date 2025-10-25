# Datadog Agent and GPG Tools Installation Script
# Installs Datadog agent and GPG tools for BOFA environment

param(
    [string]$Environment = "Prod",
    [bool]$InstallDatadog = $true,
    [bool]$InstallGPG = $true,
    [string]$DatadogApiKey = $null  # Should be provided via Key Vault or secure parameter
)

$stagingDir = "C:\TEMP"

Write-Host "Starting Datadog and GPG installation for $Environment environment..." -ForegroundColor Cyan

# Environment-specific Datadog configuration
$datadogConfig = @{
    "Prod" = @{
        site = "datadoghq.com"
        tags = "env:prod,client:bofa,tier:application"
    }
    "Dev" = @{
        site = "datadoghq.com"
        tags = "env:dev,client:bofa,tier:application"
    }
}

try {
    Set-Location -Path $stagingDir

    # Install Datadog Agent
    if ($InstallDatadog) {
        Write-Host "Installing Datadog Agent..." -ForegroundColor Cyan

        # Download Datadog agent
        $datadogUrl = "https://s3.amazonaws.com/ddagent-windows-stable/datadog-agent-7-latest.amd64.msi"
        $datadogMsi = "$stagingDir\datadog-agent.msi"

        Write-Host "Downloading Datadog Agent..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri $datadogUrl -OutFile $datadogMsi
            Write-Host "Datadog Agent downloaded successfully." -ForegroundColor Green
        } catch {
            Write-Warning "Failed to download Datadog Agent: $_"
            Write-Host "Continuing with other installations..." -ForegroundColor Yellow
            $InstallDatadog = $false
        }

        if ($InstallDatadog) {
            # Prepare installation arguments
            $ddArgs = @("/i", $datadogMsi, "/qn")

            # Add API key if provided
            if ($DatadogApiKey) {
                $ddArgs += "APIKEY=$DatadogApiKey"
                Write-Host "Using provided API key for Datadog installation." -ForegroundColor Green
            } else {
                Write-Warning "No Datadog API key provided. Agent will need manual configuration."
                Write-Host "Set DATADOG_API_KEY environment variable or configure via datadog.yaml" -ForegroundColor Yellow
            }

            # Add environment-specific configuration
            $envConfig = $datadogConfig[$Environment]
            if ($envConfig) {
                $ddArgs += "SITE=$($envConfig.site)"
                $ddArgs += "TAGS=$($envConfig.tags)"
                Write-Host "Environment: $Environment, Site: $($envConfig.site)" -ForegroundColor White
                Write-Host "Tags: $($envConfig.tags)" -ForegroundColor White
            }

            # Install Datadog agent
            Write-Host "Installing Datadog Agent (this may take a few minutes)..." -ForegroundColor Cyan
            $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $ddArgs -Wait -PassThru -NoNewWindow

            if ($process.ExitCode -eq 0) {
                Write-Host "Datadog Agent installed successfully." -ForegroundColor Green

                # Start Datadog service
                try {
                    Start-Service -Name "DatadogAgent" -ErrorAction Stop
                    Write-Host "Datadog Agent service started." -ForegroundColor Green
                } catch {
                    Write-Warning "Failed to start Datadog service: $_"
                }

                # Configure additional settings if needed
                $datadogConfDir = "$env:ProgramData\Datadog"
                if (Test-Path $datadogConfDir) {
                    Write-Host "Datadog configuration directory: $datadogConfDir" -ForegroundColor White

                    # Create basic datadog.yaml if it doesn't exist and we have API key
                    $datadogYaml = "$datadogConfDir\datadog.yaml"
                    if (-not (Test-Path $datadogYaml) -and $DatadogApiKey) {
                        $yamlContent = @"
api_key: $DatadogApiKey
site: $($envConfig.site)
tags:
  - $($envConfig.tags -replace ',', "`n  - ")
logs_enabled: true
process_config:
  enabled: "true"
"@
                        $yamlContent | Out-File -FilePath $datadogYaml -Encoding UTF8
                        Write-Host "Created basic datadog.yaml configuration." -ForegroundColor Green
                    }
                }
            } else {
                Write-Warning "Datadog Agent installation failed with exit code: $($process.ExitCode)"
            }

            # Clean up installer
            Remove-Item -Path $datadogMsi -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host "Datadog installation skipped." -ForegroundColor Yellow
    }

    # Install GPG (GnuPG)
    if ($InstallGPG) {
        Write-Host "Installing GPG (GnuPG)..." -ForegroundColor Cyan

        # Download GPG4Win (includes GnuPG)
        $gpgUrl = "https://files.gpg4win.org/gpg4win-latest.exe"
        $gpgInstaller = "$stagingDir\gpg4win-latest.exe"

        Write-Host "Downloading GPG4Win..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri $gpgUrl -OutFile $gpgInstaller
            Write-Host "GPG4Win downloaded successfully." -ForegroundColor Green
        } catch {
            Write-Warning "Failed to download GPG4Win: $_"

            # Try alternative: Chocolatey installation if available
            if (Get-Command choco -ErrorAction SilentlyContinue) {
                Write-Host "Attempting GPG installation via Chocolatey..." -ForegroundColor Yellow
                try {
                    & choco install gnupg -y
                    Write-Host "GPG installed via Chocolatey." -ForegroundColor Green
                    $InstallGPG = $false  # Skip manual installation
                } catch {
                    Write-Warning "Chocolatey GPG installation also failed: $_"
                    $InstallGPG = $false
                }
            } else {
                $InstallGPG = $false
            }
        }

        if ($InstallGPG -and (Test-Path $gpgInstaller)) {
            # Install GPG4Win silently
            Write-Host "Installing GPG4Win (this may take a few minutes)..." -ForegroundColor Cyan
            $gpgArgs = @("/S")  # Silent installation

            $process = Start-Process -FilePath $gpgInstaller -ArgumentList $gpgArgs -Wait -PassThru -NoNewWindow

            if ($process.ExitCode -eq 0) {
                Write-Host "GPG4Win installed successfully." -ForegroundColor Green

                # Add GPG to PATH if not already there
                $gpgPath = "${env:ProgramFiles(x86)}\GnuPG\bin"
                if (Test-Path $gpgPath) {
                    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
                    if ($currentPath -notlike "*$gpgPath*") {
                        $newPath = $currentPath + ";$gpgPath"
                        [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
                        Write-Host "Added GPG to system PATH: $gpgPath" -ForegroundColor Green
                    }

                    # Test GPG installation
                    $env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine")
                    try {
                        $gpgVersion = & gpg --version 2>$null | Select-Object -First 1
                        Write-Host "GPG installation verified: $gpgVersion" -ForegroundColor Green
                    } catch {
                        Write-Warning "Could not verify GPG installation."
                    }
                } else {
                    Write-Warning "GPG installation directory not found at expected location."
                }
            } else {
                Write-Warning "GPG4Win installation failed with exit code: $($process.ExitCode)"
            }

            # Clean up installer
            Remove-Item -Path $gpgInstaller -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host "GPG installation skipped." -ForegroundColor Yellow
    }

    # Display installation summary
    Write-Host "`n=== Installation Summary ===" -ForegroundColor Cyan
    Write-Host "Environment: $Environment" -ForegroundColor White

    if ($InstallDatadog) {
        $datadogService = Get-Service -Name "DatadogAgent" -ErrorAction SilentlyContinue
        if ($datadogService) {
            Write-Host "Datadog Agent: Installed (Status: $($datadogService.Status))" -ForegroundColor White
            if ($DatadogApiKey) {
                Write-Host "  - API Key: Configured" -ForegroundColor White
            } else {
                Write-Host "  - API Key: NOT CONFIGURED - Manual setup required" -ForegroundColor Red
            }
            Write-Host "  - Configuration: $env:ProgramData\Datadog\datadog.yaml" -ForegroundColor White
        } else {
            Write-Host "Datadog Agent: Installation Failed" -ForegroundColor Red
        }
    } else {
        Write-Host "Datadog Agent: Skipped" -ForegroundColor Yellow
    }

    if ($InstallGPG) {
        try {
            $gpgCheck = & gpg --version 2>$null | Select-Object -First 1
            if ($gpgCheck) {
                Write-Host "GPG (GnuPG): Installed ($gpgCheck)" -ForegroundColor White
            } else {
                Write-Host "GPG (GnuPG): Installation may have failed" -ForegroundColor Red
            }
        } catch {
            Write-Host "GPG (GnuPG): Installation status unknown" -ForegroundColor Yellow
        }
    } else {
        Write-Host "GPG (GnuPG): Skipped" -ForegroundColor Yellow
    }

    Write-Host "=============================" -ForegroundColor Cyan

    Write-Host "Additional configuration notes:" -ForegroundColor Yellow
    if ($InstallDatadog -and -not $DatadogApiKey) {
        Write-Host "1. Configure Datadog API key in $env:ProgramData\Datadog\datadog.yaml" -ForegroundColor Yellow
        Write-Host "2. Restart DatadogAgent service after configuration" -ForegroundColor Yellow
    }
    if ($InstallGPG) {
        Write-Host "3. GPG keyring setup may be required for specific use cases" -ForegroundColor Yellow
        Write-Host "4. Use 'gpg --gen-key' to generate keys if needed" -ForegroundColor Yellow
    }

    Write-Host "Installation completed successfully!" -ForegroundColor Green

} catch {
    Write-Error "Installation failed: $_"
    exit 1
}