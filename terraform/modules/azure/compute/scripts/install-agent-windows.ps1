# Azure DevOps Agent Installation - Windows Only
# Installs and configures Azure DevOps agent for deployment groups

param(
    [Parameter(Mandatory=$true)]
    [string]$OrgUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$PatToken,
    
    [Parameter(Mandatory=$true)]
    [string]$DeploymentGroup,
    
    [Parameter(Mandatory=$false)]
    [string]$AgentName = $env:COMPUTERNAME,
    
    [Parameter(Mandatory=$false)]
    [string]$Tags = "",
    
    [Parameter(Mandatory=$false)]
    [string]$WorkDirectory = "C:\ADOAgent"
)

Write-Host "=== Azure DevOps Agent Installation ===" -ForegroundColor Cyan
Write-Host "Organization URL: $OrgUrl" -ForegroundColor White
Write-Host "Deployment Group: $DeploymentGroup" -ForegroundColor White
Write-Host "Agent Name: $AgentName" -ForegroundColor White
Write-Host "Tags: $Tags" -ForegroundColor White

$ErrorActionPreference = "Stop"

try {
    # Create agent directory
    if (-not (Test-Path $WorkDirectory)) {
        New-Item -ItemType Directory -Path $WorkDirectory -Force | Out-Null
        Write-Host "✓ Created agent directory: $WorkDirectory" -ForegroundColor Green
    }

    # Check if agent is already configured
    $ConfigFile = Join-Path $WorkDirectory ".agent"
    if (Test-Path $ConfigFile) {
        Write-Host "⚠ Agent already configured. Checking status..." -ForegroundColor Yellow
        
        $Service = Get-Service -Name "vstsagent*" -ErrorAction SilentlyContinue
        if ($Service -and $Service.Status -eq "Running") {
            Write-Host "✓ Agent service is already running: $($Service.Name)" -ForegroundColor Green
            return
        }
    }

    # Download latest agent
    Write-Host "Downloading Azure DevOps agent..." -ForegroundColor Yellow
    $ApiUrl = "$OrgUrl/_apis/distributedtask/packages/agent?platform=win-x64&`$top=1"
    $Headers = @{
        Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PatToken"))
    }
    
    $AgentInfo = Invoke-RestMethod -Uri $ApiUrl -Headers $Headers -UseBasicParsing
    $DownloadUrl = $AgentInfo.value[0].downloadUrl
    
    $AgentZip = Join-Path $WorkDirectory "agent.zip"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $AgentZip -UseBasicParsing
    Write-Host "✓ Agent downloaded successfully" -ForegroundColor Green

    # Extract agent
    Expand-Archive -Path $AgentZip -DestinationPath $WorkDirectory -Force
    Remove-Item $AgentZip -Force
    Write-Host "✓ Agent extracted successfully" -ForegroundColor Green

    # Configure agent for deployment group
    Write-Host "Configuring agent for deployment group..." -ForegroundColor Yellow
    $ConfigArgs = @(
        "--unattended",
        "--deploymentgroup", 
        "--url", $OrgUrl,
        "--auth", "pat",
        "--token", $PatToken,
        "--deploymentgroupname", $DeploymentGroup,
        "--agent", $AgentName,
        "--runAsService",
        "--work", "_work",
        "--windowsLogonAccount", "NT AUTHORITY\SYSTEM",
        "--replace"
    )
    
    if ($Tags) {
        $ConfigArgs += "--addDeploymentGroupTags"
        $ConfigArgs += "--deploymentGroupTags", $Tags
    }

    $ConfigScript = Join-Path $WorkDirectory "config.cmd"
    $Process = Start-Process -FilePath $ConfigScript -ArgumentList $ConfigArgs -Wait -PassThru -NoNewWindow
    
    if ($Process.ExitCode -eq 0) {
        Write-Host "✓ Agent configured successfully" -ForegroundColor Green
        
        # Verify service
        Start-Sleep -Seconds 5
        $Service = Get-Service -Name "vstsagent*" -ErrorAction SilentlyContinue
        if ($Service -and $Service.Status -eq "Running") {
            Write-Host "✓ Agent service is running: $($Service.Name)" -ForegroundColor Green
        }
        
        # Success marker
        @{
            InstallDate = Get-Date
            AgentName = $AgentName
            DeploymentGroup = $DeploymentGroup
            Tags = $Tags
            OrgUrl = $OrgUrl
        } | ConvertTo-Json | Out-File -FilePath "$WorkDirectory\install_success.json" -Force
        
    } else {
        throw "Agent configuration failed with exit code: $($Process.ExitCode)"
    }

} catch {
    Write-Host "✗ ADO Agent installation failed: $($_.Exception.Message)" -ForegroundColor Red
    
    @{
        ErrorMessage = $_.Exception.Message
        ErrorTime = Get-Date
        AgentName = $AgentName
        DeploymentGroup = $DeploymentGroup
    } | ConvertTo-Json | Out-File -FilePath "$WorkDirectory\install_error.json" -Force
    
    throw
}

Write-Host "=== ADO Agent Installation Completed ===" -ForegroundColor Green