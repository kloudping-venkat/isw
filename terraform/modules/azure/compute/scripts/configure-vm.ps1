param(
    [Parameter(Mandatory=$false)]
    [string]$AdoPat = "",

    [Parameter(Mandatory=$false)]
    [switch]$InstallAdoAgent,

    [Parameter(Mandatory=$false)]
    [string]$AdoOrgUrl = "",

    [Parameter(Mandatory=$false)]
    [string]$AdoDeploymentPool = "",

    [Parameter(Mandatory=$false)]
    [string]$AdoAgentName = "",

    [Parameter(Mandatory=$false)]
    [string]$AdoServiceUser = "CertentEMBOFA.Prod\svc_appsrv_ado1$",

    [Parameter(Mandatory=$false)]
    [string]$AdoServicePassword = "",

    [Parameter(Mandatory=$false)]
    [int]$ExpectedDiskCount = 0,

    [Parameter(Mandatory=$false)]
    [string]$VmRole = "",

    [Parameter(Mandatory=$false)]
    [string]$AdminUsername = "",

    [Parameter(Mandatory=$false)]
    [string]$AppServiceAccount = "" # gMSA account for APP servers (e.g., "svc_appsrv_wm$")
)

# Variable to hold the status of each stage
$statusLog = @{
    "Stage 0: System Preparation" = "Not Started"
    "Stage 1: Enhanced Disk Provisioning" = "Not Started"
    "Stage 2: Azure DevOps Agent Installation" = "Not Started"
    "Stage 3: Server Role Configuration" = "Not Started"
    "Stage 4: Tanium Installation" = "Not Started"
    "Stage 5: Oracle Client Installation" = "Not Started"
    "Stage 6: GPG Tool Installation" = "Not Started"
    "Stage 7: Domain Join" = "Not Started"
}

# Create temp directory for logging and start transcript
New-Item -ItemType Directory -Path 'C:\temp' -Force | Out-Null
$logFile = 'C:\temp\vm_configuration.log'

Start-Transcript -Path $logFile -Append -Force

Write-Host '=== BOFA VM Configuration ===' -ForegroundColor Cyan
Write-Host "VM Name: $env:COMPUTERNAME" -ForegroundColor White
Write-Host "Role: $VmRole" -ForegroundColor White
Write-Host "Install ADO Agent: $InstallAdoAgent" -ForegroundColor White
Write-Host "Expected Disk Count: $ExpectedDiskCount" -ForegroundColor White

# If ExpectedDiskCount is not set or 0, auto-detect from attached data disks
if ($ExpectedDiskCount -eq 0 -or [string]::IsNullOrEmpty($ExpectedDiskCount)) {
  Write-Host "[WARNING] ExpectedDiskCount not provided or is 0, will auto-detect data disks" -ForegroundColor Yellow
  # Auto-detect: count all non-boot, non-OS disks
  $autoDetectedDisks = Get-Disk | Where-Object { -not $_.IsBoot -and $_.Number -ne 0 }
  $ExpectedDiskCount = $autoDetectedDisks.Count
  Write-Host "[INFO] Auto-detected $ExpectedDiskCount data disks" -ForegroundColor Cyan
}

Write-Host "=== VM Configuration Started: $(Get-Date) ===" -ForegroundColor Cyan

# Stage 0: System Preparation
Write-Host 'Stage 0: System Preparation' -ForegroundColor Yellow
try {
  Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine -Force

  # Ensure admin user is in local Administrators group for RDP troubleshooting
  if ($AdminUsername -ne "") {
    Write-Host "Ensuring $AdminUsername is in local Administrators group..." -ForegroundColor Cyan
    try {
      $adminGroup = [ADSI]"WinNT://$env:COMPUTERNAME/Administrators,group"
      $members = @($adminGroup.Invoke("Members")) | ForEach-Object { ([ADSI]$_).InvokeGet("Name") }

      if ($members -notcontains $AdminUsername) {
        $adminGroup.Add("WinNT://$env:COMPUTERNAME/$AdminUsername")
        Write-Host "[OK] Added $AdminUsername to local Administrators group" -ForegroundColor Green
      } else {
        Write-Host "[INFO] $AdminUsername is already in local Administrators group" -ForegroundColor Cyan
      }
    } catch {
      Write-Host "[WARNING] Could not add $AdminUsername to Administrators: $($_.Exception.Message)" -ForegroundColor Yellow
    }
  } else {
    Write-Host "[INFO] AdminUsername not provided, skipping admin user configuration" -ForegroundColor Yellow
  }

  $statusLog."Stage 0: System Preparation" = "Success"
} catch {
  $statusLog."Stage 0: System Preparation" = "Failed"
  Write-Host "[ERROR] System Preparation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Stage 1: Enhanced Disk Provisioning with Verification
Write-Host 'Stage 1: Enhanced Disk Provisioning' -ForegroundColor Yellow
try {
  Write-Host 'Waiting for Azure data disks to be fully recognized...' -ForegroundColor Cyan
  $maxWaitSeconds = 180
  $sleepInterval = 5
  $disksReady = $false
  $elapsedTime = 0
  if ($ExpectedDiskCount -eq 0) {
    Write-Host "[INFO] No data disks expected, skipping disk provisioning." -ForegroundColor Cyan
    $disksReady = $true
  } else {
    while (-not $disksReady -and $elapsedTime -lt $maxWaitSeconds) {
      $dataDisks = Get-Disk | Where-Object { -not $_.IsBoot -and $_.Number -ne 0 }
      $rawDisks = $dataDisks | Where-Object { $_.PartitionStyle -eq 'RAW' }
      Write-Host "Found $($dataDisks.Count) data disks total ($($rawDisks.Count) RAW, $($dataDisks.Count - $rawDisks.Count) already initialized)" -ForegroundColor Cyan
      if ($dataDisks.Count -ge $ExpectedDiskCount) {
        $disksReady = $true
        Write-Host "[OK] All expected data disks detected." -ForegroundColor Green
      } else {
        Write-Host "Disks not yet ready. Found $($dataDisks.Count) of $ExpectedDiskCount expected. Waiting..." -ForegroundColor Yellow
        Start-Sleep -Seconds $sleepInterval
        $elapsedTime += $sleepInterval
      }
    }
  }
  Write-Host "[OK] Disk detection complete. Proceeding with disk provisioning..." -ForegroundColor Green
  $dvd = Get-WmiObject Win32_Volume | Where-Object { $_.DriveType -eq 5 -and $_.DriveLetter -eq 'E:' }
  if ($dvd) { Set-WmiInstance -InputObject $dvd -Arguments @{DriveLetter='X:'}; Write-Host 'Moved DVD drive from E: to X:' -ForegroundColor Green }
  if ($VmRole -eq "WebServer") {
      Write-Host 'Provisioning WEB server disks (128GB->F:, 50GB->R:)...' -ForegroundColor Cyan
      $diskMap = @{ 128 = 'F'; 50 = 'R' }
      foreach ($sizeGB in $diskMap.Keys) {
        $driveLetter = $diskMap[$sizeGB]
        $existingVolume = Get-Volume -DriveLetter $driveLetter -ErrorAction SilentlyContinue
        if ($existingVolume) { Write-Host "Drive $driveLetter already exists, skipping" -ForegroundColor Yellow; continue }
        $disk = Get-Disk | Where-Object { $_.OperationalStatus -eq 'Online' -and $_.PartitionStyle -eq 'RAW' -and -not $_.IsBoot -and [math]::Abs([math]::Round($_.Size/1GB) - $sizeGB) -le 3 } | Select-Object -First 1
        if ($disk) {
          try {
            Write-Host "Attempting to configure $($sizeGB)GB disk as ${driveLetter}:" -ForegroundColor Cyan
            $disk | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -UseMaximumSize -DriveLetter $driveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "WebData$driveLetter" -Confirm:$false -Force -ErrorAction Stop
            Write-Host "[OK] Configured $([math]::Round($disk.Size/1GB))GB disk as ${driveLetter}:" -ForegroundColor Green
          } catch { throw "Disk provisioning failed" }
        } else { Write-Host "[ERROR] No suitable disk found for ${driveLetter}: ($sizeGB GB)" -ForegroundColor Red; throw "Disk provisioning failed" }
      }
  } elseif ($VmRole -eq "ADOAgent") {
      Write-Host 'Provisioning ADO agent disks (128GB->E:, 128GB->R:)...' -ForegroundColor Cyan
      $diskMap = @( @{ size = 128; driveLetter = 'E' }, @{ size = 128; driveLetter = 'R' } )
      foreach ($diskConfig in $diskMap) {
        $sizeGB = $diskConfig.size
        $driveLetter = $diskConfig.driveLetter
        $existingVolume = Get-Volume -DriveLetter $driveLetter -ErrorAction SilentlyContinue
        if ($existingVolume) { Write-Host "Drive $driveLetter already exists, skipping" -ForegroundColor Yellow; continue }
        $disk = Get-Disk | Where-Object { $_.OperationalStatus -eq 'Online' -and $_.PartitionStyle -eq 'RAW' -and -not $_.IsBoot -and [math]::Abs([math]::Round($_.Size/1GB) - $sizeGB) -le 3 } | Select-Object -First 1
        if ($disk) {
          try {
            Write-Host "Attempting to configure $($sizeGB)GB disk as ${driveLetter}:" -ForegroundColor Cyan
            $disk | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -UseMaximumSize -DriveLetter $driveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "ADOData$driveLetter" -Confirm:$false -Force -ErrorAction Stop
            Write-Host "[OK] Configured $([math]::Round($disk.Size/1GB))GB disk as ${driveLetter}:" -ForegroundColor Green
          } catch { throw "Disk provisioning failed" }
        } else { Write-Host "[ERROR] No suitable disk found for ${driveLetter}: ($sizeGB GB)" -ForegroundColor Red; throw "Disk provisioning failed" }
      }
  } elseif ($VmRole -eq "ApplicationServer") {
      Write-Host 'Provisioning APP server disks (128GB->E:, 50GB->R:)...' -ForegroundColor Cyan
      $diskMap = @{ 128 = 'E'; 50 = 'R' }
      foreach ($sizeGB in $diskMap.Keys) {
        $driveLetter = $diskMap[$sizeGB]
        $existingVolume = Get-Volume -DriveLetter $driveLetter -ErrorAction SilentlyContinue
        if ($existingVolume) { Write-Host "Drive $driveLetter already exists, skipping" -ForegroundColor Yellow; continue }
        $disk = Get-Disk | Where-Object { $_.OperationalStatus -eq 'Online' -and $_.PartitionStyle -eq 'RAW' -and -not $_.IsBoot -and [math]::Abs([math]::Round($_.Size/1GB) - $sizeGB) -le 3 } | Select-Object -First 1
        if ($disk) {
          try {
            Write-Host "Attempting to configure $($sizeGB)GB disk as ${driveLetter}:" -ForegroundColor Cyan
            $disk | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -UseMaximumSize -DriveLetter $driveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "AppData$driveLetter" -Confirm:$false -Force -ErrorAction Stop
            Write-Host "[OK] Configured $([math]::Round($disk.Size/1GB))GB disk as ${driveLetter}:" -ForegroundColor Green
          } catch { throw "Disk provisioning failed" }
        } else { Write-Host "[ERROR] No suitable disk found for ${driveLetter}: ($sizeGB GB)" -ForegroundColor Red; throw "Disk provisioning failed" }
      }
  }
  $statusLog."Stage 1: Enhanced Disk Provisioning" = "Success"
} catch {
  $statusLog."Stage 1: Enhanced Disk Provisioning" = "Failed"
  Write-Host "[ERROR] Disk provisioning failed with a critical error. $($_.Exception.Message)" -ForegroundColor Red
}

# Stage 2: Azure DevOps Agent Installation
Write-Host 'Stage 2: Azure DevOps Agent Installation' -ForegroundColor Yellow
try {
  # Check if VM is domain-joined - ADO agent with gMSA can only be installed after domain join
  $computerSystem = Get-WmiObject -Class Win32_ComputerSystem

  if ($AdoOrgUrl -ne "" -and $AdoPat -ne "" -and $AdoDeploymentPool -ne "") {
    # Check if using gMSA account
    if ($AdoServiceUser -ne "" -and $AdoServiceUser -like "*$") {
      if (-not $computerSystem.PartOfDomain) {
        Write-Host "[INFO] gMSA account detected but VM is not domain-joined yet." -ForegroundColor Yellow
        Write-Host "[INFO] ADO agent installation will be completed after domain join and restart." -ForegroundColor Yellow
        $statusLog."Stage 2: Azure DevOps Agent Installation" = "Deferred (Awaiting Domain Join)"
      } else {
        # VM is domain-joined, we can install ADO agent with gMSA
        Write-Host 'Installing Azure DevOps Agent for Deployment Pool...' -ForegroundColor Cyan
        Write-Host "[INFO] ADO agent will run as: $AdoServiceUser" -ForegroundColor Cyan
        Write-Host "[DEBUG] PAT token length: $($AdoPat.Length) characters" -ForegroundColor Yellow
        Write-Host "[DEBUG] PAT token starts with: $($AdoPat.Substring(0, [Math]::Min(4, $AdoPat.Length)))..." -ForegroundColor Yellow

        # Add gMSA to local Administrators BEFORE configuring agent
        Write-Host "[INFO] VM is domain-joined. Adding gMSA to local Administrators..." -ForegroundColor Cyan
        try {
          # Parse domain and username
          $domainName = ""
          $justUsername = ""
          if ($AdoServiceUser -like "*\*") {
            $parts = $AdoServiceUser.Split('\')
            $domainName = $parts[0]
            $justUsername = $parts[1]
          } else {
            $justUsername = $AdoServiceUser
          }

          $adminGroup = [ADSI]"WinNT://$env:COMPUTERNAME/Administrators,group"
          $members = @($adminGroup.Invoke("Members")) | ForEach-Object { ([ADSI]$_).InvokeGet("Name") }

          if ($members -notcontains $justUsername) {
            if ($domainName -ne "") {
              $adminGroup.Add("WinNT://$domainName/$justUsername")
            } else {
              $adminGroup.Add("WinNT://$justUsername")
            }
            Write-Host "[OK] Added $AdoServiceUser to local Administrators group" -ForegroundColor Green
          } else {
            Write-Host "[INFO] $AdoServiceUser is already in local Administrators group" -ForegroundColor Cyan
          }
        } catch {
          Write-Host "[WARNING] Could not add gMSA to Administrators: $($_.Exception.Message)" -ForegroundColor Yellow
          Write-Host "[WARNING] Agent configuration may fail without local admin rights" -ForegroundColor Yellow
        }

        # Proceed with agent installation since we're domain-joined
        $agentPath = 'C:\azagent'
        $agentService = Get-Service -Name 'vstsagent*' -ErrorAction SilentlyContinue

    # Check if agent is already installed
    if ($agentService) {
        Write-Host "[INFO] ADO agent service found: $($agentService.Name)" -ForegroundColor Cyan
        Write-Host "[INFO] Current status: $($agentService.Status)" -ForegroundColor Cyan

        # Stop the service if running
        if ($agentService.Status -eq 'Running') {
            Write-Host "Stopping ADO agent service..." -ForegroundColor Yellow
            Stop-Service -Name $agentService.Name -Force
            Start-Sleep -Seconds 5
            Write-Host "[OK] ADO agent service stopped" -ForegroundColor Green
        }

        # Unconfigure the existing agent
        Write-Host "Unconfiguring existing ADO agent..." -ForegroundColor Yellow
        $unconfigScript = Join-Path $agentPath 'config.cmd'
        if (Test-Path $unconfigScript) {
            $process = Start-Process -FilePath $unconfigScript -ArgumentList 'remove', '--unattended', '--auth', 'pat', '--token', $AdoPat -Wait -PassThru -NoNewWindow
            if ($process.ExitCode -eq 0) {
                Write-Host "[OK] Existing agent unconfigured successfully" -ForegroundColor Green
            } else {
                Write-Host "[WARNING] Agent unconfigure returned exit code: $($process.ExitCode)" -ForegroundColor Yellow
            }
        }

        Write-Host "Reconfiguring ADO agent with new settings..." -ForegroundColor Cyan
    } else {
        Write-Host "[INFO] No existing ADO agent found. Proceeding with fresh installation..." -ForegroundColor Cyan
    }

    # Download and install agent if not already present
    $configScript = Join-Path $agentPath 'config.cmd'
    $needsDownload = -not (Test-Path $configScript)

    if ($needsDownload) {
        Write-Host "Downloading and installing ADO agent..." -ForegroundColor Cyan
        if (-not (Test-Path $agentPath)) {
          New-Item -ItemType Directory -Path $agentPath -Force | Out-Null
          Write-Host "[OK] Created agent directory: $agentPath" -ForegroundColor Green
        }
        Write-Host 'Downloading Azure DevOps agent...' -ForegroundColor Cyan
        $agentZip = "$agentPath\agent.zip"
        $apiUrl = "$AdoOrgUrl/_apis/distributedtask/packages/agent?platform=win-x64&`$top=1"
        $headers = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(':' + $AdoPat)) }
        Write-Host 'Fetching latest agent version info...' -ForegroundColor Cyan
        $agentInfo = Invoke-RestMethod -Uri $apiUrl -Headers $headers -UseBasicParsing -TimeoutSec 30
        $downloadUrl = $agentInfo.value[0].downloadUrl
        Write-Host "Downloading agent from: $downloadUrl" -ForegroundColor Cyan
        Write-Host 'This may take 2-5 minutes depending on network speed...' -ForegroundColor Yellow
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add('Authorization', 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(':' + $AdoPat)))
        $webClient.DownloadFile($downloadUrl, $agentZip)
        $webClient.Dispose()
        Write-Host '[OK] Agent downloaded successfully' -ForegroundColor Green
        Write-Host 'Extracting agent...' -ForegroundColor Cyan
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($agentZip)
        foreach ($entry in $zip.Entries) {
            $targetPath = Join-Path $agentPath $entry.FullName
            $targetDir = Split-Path $targetPath -Parent
            if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
            if ($entry.Length -gt 0) { [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $targetPath, $true) }
        }
        $zip.Dispose()
        Write-Host '[OK] Agent extracted successfully' -ForegroundColor Green
        Remove-Item $agentZip -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "[INFO] Agent binaries already present, skipping download" -ForegroundColor Cyan
    }

    # Note: gMSA account will be added to Administrators after domain join (Stage 7)

    $agentName = if ($AdoAgentName -ne "") { $AdoAgentName } else { $env:COMPUTERNAME }

    # Check if agent is already configured and remove it first
    Push-Location $agentPath
    $configFile = Join-Path $agentPath '.agent'
    if (Test-Path $configFile) {
      Write-Host "[INFO] Agent is already configured. Removing existing configuration..." -ForegroundColor Yellow
      try {
        $removeScript = Join-Path $agentPath 'config.cmd'
        $removeArgs = @('remove', '--auth', 'pat', '--token', $AdoPat)
        $removeProcess = Start-Process -FilePath $removeScript -ArgumentList $removeArgs -Wait -PassThru -NoNewWindow
        if ($removeProcess.ExitCode -eq 0) {
          Write-Host "[OK] Existing agent configuration removed successfully" -ForegroundColor Green
        } else {
          Write-Host "[WARNING] Failed to remove existing configuration (exit code: $($removeProcess.ExitCode))" -ForegroundColor Yellow
        }
      } catch {
        Write-Host "[WARNING] Could not remove existing agent configuration: $($_.Exception.Message)" -ForegroundColor Yellow
      }
    }
    Pop-Location

    # Configure agent - Use two-step approach for gMSA accounts
    # Step 1: Configure with NETWORK SERVICE (always works)
    # Step 2: Change Windows service to use gMSA account via WMI

    if ($AdoServiceUser -ne "" -and $AdoServiceUser -like "*$") {
      Write-Host "Configuring ADO agent with gMSA: $AdoServiceUser" -ForegroundColor Cyan
      Write-Host "[INFO] Using two-step approach: NETWORK SERVICE -> gMSA" -ForegroundColor Cyan

      # Step 1: Configure agent with NETWORK SERVICE
      Write-Host "Step 1: Installing agent with NETWORK SERVICE..." -ForegroundColor Cyan
      $configArgs = @(
        '--unattended', '--deploymentpool', '--deploymentpoolname', $AdoDeploymentPool,
        '--url', $AdoOrgUrl, '--auth', 'pat', '--token', $AdoPat, '--agent', $agentName,
        '--runAsService', '--work', '_work',
        '--windowsLogonAccount', 'NT AUTHORITY\NETWORK SERVICE',
        '--replace'
      )

      $configScript = Join-Path $agentPath 'config.cmd'
      $process = Start-Process -FilePath $configScript -ArgumentList $configArgs -Wait -PassThru -NoNewWindow

      if ($process.ExitCode -eq 0) {
        Write-Host '[OK] Agent configured with NETWORK SERVICE' -ForegroundColor Green

        # Step 2: Change service account to gMSA
        Write-Host "Step 2: Changing service account to gMSA..." -ForegroundColor Cyan
        Start-Sleep -Seconds 3

        $serviceName = (Get-Service -Name "vstsagent*" -ErrorAction SilentlyContinue).Name
        if ($serviceName) {
          # Stop the service
          Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
          Start-Sleep -Seconds 2

          # Change service account to gMSA (empty password for gMSA)
          $service = Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'"
          $changeResult = $service.Change($null, $null, $null, $null, $null, $null, $AdoServiceUser, "")

          if ($changeResult.ReturnValue -eq 0) {
            Write-Host "[OK] Service account changed to: $AdoServiceUser" -ForegroundColor Green

            # Start the service
            Start-Service -Name $serviceName -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3

            $svc = Get-Service -Name $serviceName
            if ($svc.Status -eq 'Running') {
              Write-Host "[OK] ADO agent service is running as gMSA!" -ForegroundColor Green
              $statusLog."Stage 2: Azure DevOps Agent Installation" = "Success"
            } else {
              Write-Host "[WARNING] Service status: $($svc.Status)" -ForegroundColor Yellow
              Write-Host "[WARNING] May need manual start or gMSA permissions check" -ForegroundColor Yellow
              $statusLog."Stage 2: Azure DevOps Agent Installation" = "Partial (Service Not Running)"
            }
          } else {
            Write-Host "[ERROR] Failed to change service account (WMI Error: $($changeResult.ReturnValue))" -ForegroundColor Red
            Write-Host "[WARNING] Agent is running as NETWORK SERVICE instead of gMSA" -ForegroundColor Yellow
            $statusLog."Stage 2: Azure DevOps Agent Installation" = "Partial (Wrong Service Account)"
          }
        } else {
          Write-Host "[ERROR] Could not find ADO agent service" -ForegroundColor Red
          throw "Agent service not found after installation"
        }
      } else {
        throw "Agent configuration failed with exit code: $($process.ExitCode)"
      }

    } elseif ($AdoServiceUser -ne "" -and $AdoServicePassword -ne "") {
      # Regular domain account with password
      Write-Host "[INFO] Using regular domain service account with password" -ForegroundColor Cyan
      $configArgs = @(
        '--unattended', '--deploymentpool', '--deploymentpoolname', $AdoDeploymentPool,
        '--url', $AdoOrgUrl, '--auth', 'pat', '--token', $AdoPat, '--agent', $agentName,
        '--runAsService', '--work', '_work',
        '--windowsLogonAccount', $AdoServiceUser,
        '--windowsLogonPassword', $AdoServicePassword,
        '--replace'
      )

      $configScript = Join-Path $agentPath 'config.cmd'
      $process = Start-Process -FilePath $configScript -ArgumentList $configArgs -Wait -PassThru -NoNewWindow
      if ($process.ExitCode -eq 0) {
        Write-Host '[OK] Agent configured successfully' -ForegroundColor Green
        $statusLog."Stage 2: Azure DevOps Agent Installation" = "Success"
      } else {
        throw "Agent configuration failed with exit code: $($process.ExitCode)"
      }

    } else {
      # No service account specified
      Write-Host "[WARNING] No ADO service account provided, using NT AUTHORITY\SYSTEM" -ForegroundColor Yellow
      $configArgs = @(
        '--unattended', '--deploymentpool', '--deploymentpoolname', $AdoDeploymentPool,
        '--url', $AdoOrgUrl, '--auth', 'pat', '--token', $AdoPat, '--agent', $agentName,
        '--runAsService', '--work', '_work',
        '--windowsLogonAccount', 'NT AUTHORITY\SYSTEM',
        '--replace'
      )

      $configScript = Join-Path $agentPath 'config.cmd'
      $process = Start-Process -FilePath $configScript -ArgumentList $configArgs -Wait -PassThru -NoNewWindow
      if ($process.ExitCode -eq 0) {
        Write-Host '[OK] Agent configured successfully' -ForegroundColor Green
        $statusLog."Stage 2: Azure DevOps Agent Installation" = "Success"
      } else {
        throw "Agent configuration failed with exit code: $($process.ExitCode)"
      }
    }
      } # End of domain-joined gMSA block
    } # End of gMSA check
  } else {
    Write-Host '[INFO] Azure DevOps Agent Installation - SKIPPED (parameters not provided)' -ForegroundColor Yellow
    $statusLog."Stage 2: Azure DevOps Agent Installation" = "Skipped (No Parameters)"
  }
} catch {
  $statusLog."Stage 2: Azure DevOps Agent Installation" = "Failed"
  Write-Host "[ERROR] ADO Agent installation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Stage 3: Server Role Configuration
Write-Host 'Stage 3: Server Role Configuration' -ForegroundColor Yellow
try {
  if ($VmRole -eq "WebServer") {
    Write-Host 'Setting up IIS Web Server...' -ForegroundColor Cyan
    Install-WindowsFeature -Name Web-Server,Web-Common-Http,Web-Http-Errors,Web-Http-Redirect,Web-App-Dev,Web-Net-Ext45,Web-Asp-Net45,Web-ISAPI-Ext,Web-ISAPI-Filter,Web-Mgmt-Tools,Web-Mgmt-Console -IncludeManagementTools -ErrorAction Stop
    Write-Host '[OK] IIS installed successfully' -ForegroundColor Green
    $defaultPage = "<html><body><h1>BOFA Web Server</h1><p>Server: $env:COMPUTERNAME</p></body></html>"
    $defaultPage | Out-File -FilePath 'C:\inetpub\wwwroot\Default.htm' -Force
    Write-Host '[OK] Default page configured' -ForegroundColor Green
    Write-Host 'Installing ASP.NET Core Hosting Bundles...' -ForegroundColor Cyan
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $wingetAvailable = $false
    try {
      $null = Get-Command winget -ErrorAction Stop
      $wingetAvailable = $true
      Write-Host "Using winget for installation..." -ForegroundColor Cyan
    } catch { Write-Host "winget not available, using dotnet-install script fallback..." -ForegroundColor Yellow }
    if ($wingetAvailable) {
      winget install --id Microsoft.DotNet.HostingBundle.6 --exact --silent --accept-source-agreements --accept-package-agreements
      Write-Host '[OK] ASP.NET Core 6.0 Hosting Bundle installed' -ForegroundColor Green
      winget install --id Microsoft.DotNet.HostingBundle.8 --exact --silent --accept-source-agreements --accept-package-agreements
      Write-Host '[OK] ASP.NET Core 8.0 Hosting Bundle installed' -ForegroundColor Green
    } else {
      Write-Host "Downloading dotnet-install.ps1 script..." -ForegroundColor Cyan
      $dotnetInstallScript = "C:\temp\dotnet-install.ps1"
      Invoke-WebRequest -Uri "https://dot.net/v1/dotnet-install.ps1" -OutFile $dotnetInstallScript -UseBasicParsing
      Write-Host "Installing ASP.NET Core 6.0 Runtime..." -ForegroundColor Cyan
      & $dotnetInstallScript -Channel 6.0 -Runtime aspnetcore -InstallDir "C:\Program Files\dotnet"
      Write-Host '[OK] ASP.NET Core 6.0 Runtime installed' -ForegroundColor Green
      Write-Host "Installing ASP.NET Core 8.0 Runtime..." -ForegroundColor Cyan
      & $dotnetInstallScript -Channel 8.0 -Runtime aspnetcore -InstallDir "C:\Program Files\dotnet"
      Write-Host '[OK] ASP.NET Core 8.0 Runtime installed' -ForegroundColor Green
      Remove-Item $dotnetInstallScript -Force -ErrorAction SilentlyContinue
    }
    Write-Host '[OK] All ASP.NET Core Hosting Bundles installed successfully' -ForegroundColor Green
    $statusLog."Stage 3: Server Role Configuration" = "Success"
  } elseif ($VmRole -eq "ADOAgent") {
    Write-Host 'Setting up ADO Agent prerequisites...' -ForegroundColor Cyan
    Install-WindowsFeature -Name NET-Framework-45-Features -IncludeManagementTools -ErrorAction Stop
    Write-Host '[OK] ADO Agent prerequisites installed' -ForegroundColor Green
    $statusLog."Stage 3: Server Role Configuration" = "Success"
  } elseif ($VmRole -eq "ApplicationServer") {
    Write-Host 'Setting up Application Server features...' -ForegroundColor Cyan
    Install-WindowsFeature -Name NET-Framework-45-Features,NET-Framework-45-Core,NET-Framework-45-ASPNET -IncludeManagementTools -ErrorAction Stop
    Write-Host '[OK] .NET Framework features installed' -ForegroundColor Green

    Write-Host 'Installing ASP.NET Core Hosting Bundles...' -ForegroundColor Cyan
    $stagingDir = "C:\TEMP"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    try {
      # ASP.NET Core 6.0.26 Hosting Bundle
      $hostingBundle6Url = "https://usngdevenvaddons.blob.core.windows.net/quarter1/dotnet-hosting-6.0.26-win.exe?sp=r&st=2025-01-31T15:23:39Z&se=2026-01-30T23:23:39Z&spr=https&sv=2022-11-02&sr=b&sig=SVI24yx5bxIMtrEx%2B1EtuIUXpkYKvnTpU%2F1GWwamTXE%3D"
      $hostingBundle6Path = "$stagingDir\dotnet-hosting-6.0.26-win.exe"
      Write-Host "Downloading ASP.NET Core 6.0.26 Hosting Bundle..." -ForegroundColor Cyan
      Invoke-WebRequest -Uri $hostingBundle6Url -OutFile $hostingBundle6Path -UseBasicParsing
      Write-Host "Installing ASP.NET Core 6.0.26 Hosting Bundle..." -ForegroundColor Cyan
      Start-Process -FilePath $hostingBundle6Path -ArgumentList "/quiet", "/norestart" -Wait -PassThru
      Write-Host '[OK] ASP.NET Core 6.0.26 Hosting Bundle installed' -ForegroundColor Green
      Remove-Item $hostingBundle6Path -Force -ErrorAction SilentlyContinue

      # ASP.NET Core 8.0 Hosting Bundle
      $hostingBundle8Url = "https://download.visualstudio.microsoft.com/download/pr/cef0eb83-0046-4e23-86aa-0d7f305c8354/e610d7ad850c2451772c3073a897bb66/dotnet-hosting-8.0.11-win.exe"
      $hostingBundle8Path = "$stagingDir\dotnet-hosting-8.0.11-win.exe"
      Write-Host "Downloading ASP.NET Core 8.0.11 Hosting Bundle..." -ForegroundColor Cyan
      Invoke-WebRequest -Uri $hostingBundle8Url -OutFile $hostingBundle8Path -UseBasicParsing
      Write-Host "Installing ASP.NET Core 8.0.11 Hosting Bundle..." -ForegroundColor Cyan
      Start-Process -FilePath $hostingBundle8Path -ArgumentList "/quiet", "/norestart" -Wait -PassThru
      Write-Host '[OK] ASP.NET Core 8.0.11 Hosting Bundle installed' -ForegroundColor Green
      Remove-Item $hostingBundle8Path -Force -ErrorAction SilentlyContinue

      Write-Host '[OK] All ASP.NET Core Hosting Bundles installed successfully' -ForegroundColor Green
    } catch {
      Write-Host "[WARNING] ASP.NET Core Hosting Bundle installation failed: $($_.Exception.Message)" -ForegroundColor Yellow
      Write-Host "Attempting fallback installation method..." -ForegroundColor Yellow
      $dotnetInstallScript = "C:\temp\dotnet-install.ps1"
      Invoke-WebRequest -Uri "https://dot.net/v1/dotnet-install.ps1" -OutFile $dotnetInstallScript -UseBasicParsing
      & $dotnetInstallScript -Channel 6.0 -Runtime aspnetcore -InstallDir "C:\Program Files\dotnet"
      Write-Host '[OK] ASP.NET Core 6.0 Runtime installed (fallback)' -ForegroundColor Green
      & $dotnetInstallScript -Channel 8.0 -Runtime aspnetcore -InstallDir "C:\Program Files\dotnet"
      Write-Host '[OK] ASP.NET Core 8.0 Runtime installed (fallback)' -ForegroundColor Green
      Remove-Item $dotnetInstallScript -Force -ErrorAction SilentlyContinue
    }
    $statusLog."Stage 3: Server Role Configuration" = "Success"
  } else {
    Write-Host "[INFO] No server role configured for this VM. Skipping." -ForegroundColor Yellow
    $statusLog."Stage 3: Server Role Configuration" = "Skipped (No Role)"
  }
} catch {
  $statusLog."Stage 3: Server Role Configuration" = "Failed"
  Write-Host "[ERROR] Server Role Configuration failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Stage 4: Tanium Installation
Write-Host 'Stage 4: Tanium Installation' -ForegroundColor Yellow
try {
  $stagingDir = "C:\TEMP"
  New-Item -Path "HKLM:\SOFTWARE\Wow6432Node\Tanium\Tanium Client\Sensor Data" -Name "Tags" -force | Out-Null
  New-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Tanium\Tanium Client\Sensor Data\Tags" -Name "Certent-EM" | Out-Null
  $ProcessCheck = (Get-Process -Name TaniumClient -ErrorAction SilentlyContinue -ErrorVariable ProcessError)
  if($null -ne $ProcessCheck) {
    Write-Host "[WARNING] Tanium is already running. Skipping installation." -ForegroundColor Yellow
    $statusLog."Stage 4: Tanium Installation" = "Skipped (Already Running)"
  } else {
    $WorkingDIR = "C:\Temp\Tanium\windows-client-bundle"
    if(!(Test-Path -Path $WorkingDIR )){
      New-Item -ItemType directory -Path $WorkingDIR | Out-Null
    }
    $source = 'https://downloads.it.insightsoftware.com/misc/Tanium/windows-client-bundle.zip'
    $destination = 'C:\Temp\Tanium\windows-client-bundle.zip'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $source -OutFile $destination
    Start-Sleep 60
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory("C:\Temp\Tanium\windows-client-bundle.zip", "C:\Temp\Tanium\windows-client-bundle")
    Set-Location "C:\Temp\Tanium\windows-client-bundle"
    .\SetupClient.exe /KeyPath="C:\Temp\Tanium\windows-client-bundle\tanium-init.dat" /S
    Start-Sleep -Seconds 360
    Write-Host "[OK] Tanium Installation Complete." -ForegroundColor Green
    $statusLog."Stage 4: Tanium Installation" = "Success"
  }
} catch {
  $statusLog."Stage 4: Tanium Installation" = "Failed"
  Write-Host "[ERROR] Tanium installation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Stage 5: Oracle Client Installation
# NOTE: Oracle installation is DISABLED per user request
# Uncomment this section when Oracle client installation is required
Write-Host 'Stage 5: Oracle Client Installation' -ForegroundColor Yellow
Write-Host '[INFO] Oracle Client installation is currently DISABLED' -ForegroundColor Yellow
$statusLog."Stage 5: Oracle Client Installation" = "Skipped (Disabled)"

<# ORACLE INSTALLATION - COMMENTED OUT
try {
    # --- CONFIGURATION FOR ORACLE CLIENT ---
    $OracleDownloadUrl = "https://usngdevenvaddons.blob.core.windows.net/quarter1/Oracle_Install_WINDOWS.X64_193000_client.zip?sp=r&st=2025-08-07T20:13:29Z&se=2026-08-08T04:28:29Z&spr=https&sv=2024-11-04&sr=b&sig=%2B7iurY8GcEOvqcZMf3VHhDnP%2Fhxzr88X3XrzF7hWSSY%3D"
    $InstallerZip = "C:\Temp\Oracle_Install_Windows.zip"
    $ExtractionPath = "C:\Temp\OracleClient\install_files"
    $ResponseFilePath = "$ExtractionPath\client.rsp"
    $OracleBase = "C:\app\client\administrator"
    $OracleHome = "C:\app\client\administrator\product\19.0.0\client_1"
    $OracleHomeName = "OraClient19c_home1"

    Write-Host "Checking for existing Oracle Client installation..." -ForegroundColor Cyan
    $oracleHomeKey = "HKLM:\SOFTWARE\Oracle\KEY_$OracleHomeName"
    if (Test-Path -Path $oracleHomeKey) {
      Write-Host "[WARNING] Oracle Client appears to be already installed. Skipping installation." -ForegroundColor Yellow
      $statusLog."Stage 5: Oracle Client Installation" = "Skipped (Already Installed)"
    } else {
      Write-Host "Starting Oracle Client Installation..." -ForegroundColor Cyan

      # Check if installer is already downloaded
      if (Test-Path $InstallerZip) {
          $fileSize = (Get-Item $InstallerZip).Length / 1MB
          Write-Host "[INFO] Oracle installer already downloaded ($([math]::Round($fileSize, 2)) MB). Skipping download." -ForegroundColor Cyan
      } else {
          # Download the Oracle Client zip file
          Write-Host "Downloading Oracle Client from blob storage (this may take 5-10 minutes)..." -ForegroundColor Cyan
          try {
              $webClient = New-Object System.Net.WebClient
              $webClient.DownloadFile($OracleDownloadUrl, $InstallerZip)
              $webClient.Dispose()
              $fileSize = (Get-Item $InstallerZip).Length / 1MB
              Write-Host "[OK] Download complete. File saved to $InstallerZip ($([math]::Round($fileSize, 2)) MB)" -ForegroundColor Green
          } catch {
              Write-Error "Failed to download the Oracle Client. Error: $_"
              throw "Oracle Client download failed"
          }
      }

      # Check if already extracted
      if (Test-Path "$ExtractionPath\client\setup.exe") {
          Write-Host "[INFO] Oracle installer files already extracted. Skipping extraction." -ForegroundColor Cyan
      } else {
          # Unzip the Oracle installation files
          Write-Host "Extracting installation files (this may take 2-3 minutes)..." -ForegroundColor Cyan
          try {
              Expand-Archive -Path $InstallerZip -DestinationPath $ExtractionPath -Force
              Write-Host "[OK] Extraction complete." -ForegroundColor Green
          } catch {
              Write-Error "Failed to extract the Oracle Client installation files. Error: $_"
              throw "Oracle Client extraction failed"
          }
      }

      # Create the response file with all your specified settings
      Write-Host "Generating the Oracle response file..." -ForegroundColor Cyan
      $ResponseFileContent = @"
ORACLE_BASE="$OracleBase"
ORACLE_HOME="$OracleHome"
ORACLE_HOME_NAME="$OracleHomeName"
oracle.install.client.installType=Administrator
DECLINE_SECURITY_UPDATES=TRUE
ORACLE_HOME_SERVICE_ACCOUNT_SELECTION=BUILTIN_ACCOUNT
"@
      
      $ResponseFileContent | Out-File -FilePath $ResponseFilePath -Encoding utf8 -Force
      Write-Host "Generated response file with your specified settings." -ForegroundColor Green

      # Find and run setup.exe
      Write-Host "Starting silent installation..." -ForegroundColor Cyan
      $InstallerExe = (Get-ChildItem -Path $ExtractionPath -Filter "setup.exe" -Recurse -ErrorAction SilentlyContinue).FullName
      if (-not $InstallerExe) {
          Write-Error "Could not find setup.exe in the extracted files. Exiting."
          throw "Installer not found"
      }

      # Define log file path
      $LogFilePath = "C:\Temp\Oracle_Install_Log.txt"
      $Arguments = "-silent -nowait -responseFile `"$ResponseFilePath`""

      # Use cmd.exe for more reliable execution of the installer
      $command = "cmd.exe /c `"$InstallerExe`" $Arguments > `"$LogFilePath`" 2>&1"

      Write-Host "Executing command: $command" -ForegroundColor White
      Invoke-Expression -Command $command

      # Wait for a reasonable time for the installer process to finish
      Write-Host "Waiting 300 seconds for Oracle Client installation to complete..." -ForegroundColor Cyan
      Start-Sleep -Seconds 300

      # Verify installation by checking registry key
      Write-Host "Verifying Oracle Client installation..." -ForegroundColor Cyan
      if (Test-Path -Path $oracleHomeKey) {
          Write-Host "[OK] Oracle Client installation completed successfully." -ForegroundColor Green
          $statusLog."Stage 5: Oracle Client Installation" = "Success"
      } else {
          Write-Host "[WARNING] Oracle Client installation may have failed. Registry key not found." -ForegroundColor Yellow
          if (Test-Path $LogFilePath) {
              Write-Host "Check log file at: $LogFilePath" -ForegroundColor Yellow
          }
          $statusLog."Stage 5: Oracle Client Installation" = "Failed"
      }

      # Clean up temporary files
      Write-Host "Cleaning up temporary files..." -ForegroundColor Cyan
      Remove-Item -Path $ExtractionPath -Recurse -Force -ErrorAction SilentlyContinue
      Remove-Item -Path $InstallerZip -Force -ErrorAction SilentlyContinue
    }
} catch {
    $statusLog."Stage 5: Oracle Client Installation" = "Failed"
    Write-Host "[ERROR] Oracle Client installation failed: $($_.Exception.Message)" -ForegroundColor Red
}
#> # END ORACLE INSTALLATION COMMENT BLOCK

# Stage 6: GPG Tool Installation
Write-Host 'Stage 6: GPG Tool Installation' -ForegroundColor Yellow
try {
  $gpgInstallPath = "C:\Program Files (x86)\GnuPG\gpg.exe"
  if (Test-Path $gpgInstallPath) {
    Write-Host "[WARNING] GPG tool is already installed. Skipping installation." -ForegroundColor Yellow
    $statusLog."Stage 6: GPG Tool Installation" = "Skipped (Already Installed)"
  } else {
    $tempDir = "C:\temp\GPG"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $installerUrl = "https://files.gpg4win.org/gpg4win-4.4.1.exe"
    $installerFile = Join-Path $tempDir "gpg4win.exe"
    Write-Host "Downloading GPG installer from $installerUrl..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerFile
    Write-Host "[OK] GPG installer downloaded." -ForegroundColor Green
    Write-Host "Installing GPG tool silently..." -ForegroundColor Cyan
    Start-Process -FilePath $installerFile -ArgumentList "/S" -Wait
    Write-Host "[OK] GPG tool installation completed." -ForegroundColor Green
    $statusLog."Stage 6: GPG Tool Installation" = "Success"
  }
} catch {
  $statusLog."Stage 6: GPG Tool Installation" = "Failed"
  Write-Host "[ERROR] GPG tool installation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Final status display
Write-Host '=== FINAL DRIVE STATUS ===' -ForegroundColor Cyan
Get-Volume | Where-Object { $_.DriveLetter -ne $null } | Sort-Object DriveLetter | ForEach-Object { Write-Host "Drive $($_.DriveLetter): $($_.FileSystemLabel) ($([math]::Round($_.Size/1GB, 2)) GB)" -ForegroundColor White }

# Stage 7 (FINAL): Domain Join - Must be last because it triggers restart
Write-Host 'Stage 7 (FINAL): Domain Join' -ForegroundColor Yellow
try {
    Write-Host "Checking domain membership..." -ForegroundColor Cyan
    $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
    if ($computerSystem.PartOfDomain) {
        Write-Host "[OK] VM is already joined to domain: $($computerSystem.Domain)" -ForegroundColor Green

        # Add ADO gMSA service account to local Administrators group (now that domain is available)
        if ($AdoServiceUser -ne "") {
          Write-Host "Adding ADO gMSA service account to local Administrators group..." -ForegroundColor Cyan
          try {
            # Parse domain and username from the service account
            $domainName = ""
            $justUsername = ""
            if ($AdoServiceUser -like "*\*") {
              $parts = $AdoServiceUser.Split('\')
              $domainName = $parts[0]
              $justUsername = $parts[1]
            } else {
              $justUsername = $AdoServiceUser
            }

            # Check if already a member
            $adminGroup = [ADSI]"WinNT://$env:COMPUTERNAME/Administrators,group"
            $members = @($adminGroup.Invoke("Members")) | ForEach-Object { ([ADSI]$_).InvokeGet("Name") }

            if ($members -notcontains $justUsername) {
              # For domain accounts, use WinNT://DOMAIN/USERNAME format
              if ($domainName -ne "") {
                $adminGroup.Add("WinNT://$domainName/$justUsername")
              } else {
                $adminGroup.Add("WinNT://$justUsername")
              }
              Write-Host "[OK] Added $AdoServiceUser to local Administrators group" -ForegroundColor Green
            } else {
              Write-Host "[INFO] $AdoServiceUser is already in local Administrators group" -ForegroundColor Yellow
            }
          } catch {
            Write-Host "[WARNING] Could not add service account to Administrators group: $($_.Exception.Message)" -ForegroundColor Yellow
          }
        }

        # Install APP server gMSA account if specified (for ApplicationServer role)
        if ($AppServiceAccount -ne "" -and $VmRole -eq "ApplicationServer") {
          Write-Host "[INFO] Installing APP server gMSA account: $AppServiceAccount" -ForegroundColor Cyan
          try {
            # Remove domain prefix if present (e.g., "DOMAIN\svc_appsrv_wm$" -> "svc_appsrv_wm$")
            $gmsaName = $AppServiceAccount
            if ($gmsaName -like "*\*") {
              $gmsaName = $gmsaName.Split('\')[1]
            }
            # Remove trailing $ for Install-ADServiceAccount
            $gmsaIdentity = $gmsaName.TrimEnd('$')

            Write-Host "[INFO] Installing gMSA: $gmsaIdentity" -ForegroundColor Cyan
            Install-ADServiceAccount -Identity $gmsaIdentity -ErrorAction Stop
            Write-Host "[OK] APP server gMSA account installed successfully!" -ForegroundColor Green

            # Add gMSA to local Administrators
            Write-Host "[INFO] Adding gMSA to local Administrators..." -ForegroundColor Cyan
            Add-LocalGroupMember -Group "Administrators" -Member "CertentEMBOFA.Prod\$gmsaName" -ErrorAction SilentlyContinue
            Write-Host "[OK] gMSA added to Administrators" -ForegroundColor Green
          } catch {
            Write-Host "[WARNING] Could not install APP server gMSA: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "[INFO] This is expected if gMSA doesn't exist yet or VM doesn't have permission" -ForegroundColor Yellow
          }
        }

        $statusLog."Stage 7: Domain Join" = "Success (Already Joined)"
    } else {
        Write-Host "VM is not domain joined. Initiating domain join..." -ForegroundColor Cyan

        # Create a scheduled task to complete configuration after restart
        # ONLY if ADO agent with gMSA needs to be configured
        if ($AdoOrgUrl -ne "" -and $AdoPat -ne "" -and $AdoServiceUser -ne "" -and $AdoServiceUser -like "*$") {
            Write-Host "Creating post-reboot configuration task for ADO agent..." -ForegroundColor Cyan
            $taskName = "Complete-ADO-Configuration"
            $scriptPath = "C:\temp\complete-ado-config.ps1"

        # Create the post-reboot script
        $postRebootScript = @"
Start-Transcript -Path 'C:\temp\post_reboot_config.log' -Append -Force
Write-Host '=== Post-Reboot ADO Configuration ===' -ForegroundColor Cyan

# Add ADO gMSA service account to local Administrators group
if ("$AdoServiceUser" -ne "") {
  Write-Host "Adding ADO gMSA service account to local Administrators group..." -ForegroundColor Cyan
  try {
    # Parse domain and username
    `$domainName = ""
    `$justUsername = ""
    if ("$AdoServiceUser" -like "*\*") {
      `$parts = "$AdoServiceUser".Split('\')
      `$domainName = `$parts[0]
      `$justUsername = `$parts[1]
    } else {
      `$justUsername = "$AdoServiceUser"
    }

    `$adminGroup = [ADSI]"WinNT://`$env:COMPUTERNAME/Administrators,group"
    `$members = @(`$adminGroup.Invoke("Members")) | ForEach-Object { ([ADSI]`$_).InvokeGet("Name") }

    if (`$members -notcontains `$justUsername) {
      # For domain accounts, use WinNT://DOMAIN/USERNAME format
      if (`$domainName -ne "") {
        `$adminGroup.Add("WinNT://`$domainName/`$justUsername")
      } else {
        `$adminGroup.Add("WinNT://`$justUsername")
      }
      Write-Host "[OK] Added $AdoServiceUser to local Administrators group" -ForegroundColor Green
    } else {
      Write-Host "[INFO] $AdoServiceUser is already in local Administrators group" -ForegroundColor Yellow
    }
  } catch {
    Write-Host "[WARNING] Could not add service account to Administrators group: `$(`$_.Exception.Message)" -ForegroundColor Yellow
  }
}

# Reconfigure ADO agent with gMSA account
if ("$AdoPat" -ne "" -and "$AdoOrgUrl" -ne "") {
  Write-Host "Reconfiguring ADO agent with gMSA account..." -ForegroundColor Cyan
  `$agentPath = "C:\azagent"

  if (Test-Path "`$agentPath\config.cmd") {
    # Remove existing configuration
    Push-Location `$agentPath
    try {
      Write-Host "Removing old agent configuration..." -ForegroundColor Cyan
      .\config.cmd remove --auth pat --token "$AdoPat"
    } catch {
      Write-Host "[WARNING] Could not remove old config: `$(`$_.Exception.Message)" -ForegroundColor Yellow
    }

    # Reconfigure with gMSA
    Write-Host "Configuring agent with gMSA account..." -ForegroundColor Cyan
    `$agentName = `$env:COMPUTERNAME
    `$configArgs = @(
      '--unattended', '--deploymentpool', '--deploymentpoolname', '$AdoDeploymentPool',
      '--url', '$AdoOrgUrl', '--auth', 'pat', '--token', '$AdoPat', '--agent', `$agentName,
      '--runAsService', '--work', '_work',
      '--windowsLogonAccount', '$AdoServiceUser',
      '--replace'
    )

    .\config.cmd @configArgs
    Write-Host "[OK] ADO agent reconfigured with gMSA account" -ForegroundColor Green
    Pop-Location
  }
}

# Remove the scheduled task
Unregister-ScheduledTask -TaskName "$taskName" -Confirm:`$false
Write-Host "[OK] Post-reboot configuration completed. Scheduled task removed." -ForegroundColor Green

Stop-Transcript
"@

        $postRebootScript | Out-File -FilePath $scriptPath -Encoding UTF8 -Force

        # Create scheduled task to run on startup
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`""
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force
        Write-Host "[OK] Post-reboot task created: $taskName" -ForegroundColor Green
        } else {
            Write-Host "[INFO] No ADO agent with gMSA to configure, skipping post-reboot task creation" -ForegroundColor Cyan
        }

        # Now join the domain
        $domainName = "CertentEMBOFA.Prod"
        $ouPath = "OU=AADDC Computers,DC=CertentEMBOFA,DC=Prod"
        $domainUser = "CertentEMBOFA.Prod\svc_domainjoin"
        $domainPassword = ConvertTo-SecureString "So9baXdkaKvIF7FiIWvo" -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($domainUser, $domainPassword)
        Write-Host "Joining domain: $domainName" -ForegroundColor Cyan
        Add-Computer -DomainName $domainName -OUPath $ouPath -Credential $credential -Restart -Force
        Write-Host "Domain join initiated. Server will restart." -ForegroundColor Green
        $statusLog."Stage 7: Domain Join" = "Success (Restarting)"
        Stop-Transcript
        exit 0
    }
} catch {
    Write-Host "[WARNING] Domain join failed: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "You may need to manually join the domain." -ForegroundColor Yellow
    $statusLog."Stage 7: Domain Join" = "Failed"
}

# --- Final Status Summary ---
Write-Host '
======================================================
  VM Configuration Summary
======================================================' -ForegroundColor White
$statusLog.Keys | Sort-Object { [int]($_.Split(':')[0].Replace('Stage','').Trim()) } | ForEach-Object {
    $status = $statusLog.$_
    $color = "Yellow"
    if ($status.StartsWith("Success")) { $color = "Green" }
    if ($status.StartsWith("Failed")) { $color = "Red" }
    Write-Host "$_`t`tStatus: $status" -ForegroundColor $color
}
Write-Host '
======================================================
' -ForegroundColor White

Write-Host "=== VM Configuration Fully Completed: $(Get-Date) ===" -ForegroundColor Green

Stop-Transcript