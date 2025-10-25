# ADO Agent Server Roles and Tools Installation Script
# Configures Windows Server for Azure DevOps Build Agent

Write-Host "=== ADO Agent Server Configuration Starting ===" -ForegroundColor Green

# Install IIS for web-based builds (if needed)
Write-Host "Installing IIS Web Server and ASP.NET features for build support..." -ForegroundColor Cyan
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole, IIS-WebServer, IIS-CommonHttpFeatures, IIS-HttpErrors, IIS-HttpRedirect, IIS-ApplicationDevelopment, IIS-NetFxExtensibility45, IIS-HealthAndDiagnostics, IIS-HttpLogging, IIS-Security, IIS-RequestFiltering, IIS-Performance, IIS-WebServerManagementTools, IIS-ManagementConsole, IIS-IIS6ManagementCompatibility, IIS-Metabase, IIS-ASPNET45 -All

# Install .NET Framework features
Write-Host "Installing .NET Framework features..." -ForegroundColor Cyan
Enable-WindowsOptionalFeature -Online -FeatureName NetFx4Extended-ASPNET45, IIS-NetFxExtensibility45, IIS-ISAPIExtensions, IIS-ISAPIFilter, IIS-ASPNET45 -All

# Download and install ASP.NET Core Hosting Bundle 6.0.26
Write-Host "Downloading and installing ASP.NET Core Hosting Bundle 6.0.26..." -ForegroundColor Cyan
$hostingBundle6Url = "https://download.visualstudio.microsoft.com/download/pr/10b77709-a6c8-41ad-9078-6a46cee89f6d/9c73b2d3e9d5ed5b4a75c3da55e8b3eb/dotnet-hosting-6.0.26-win.exe"
$hostingBundle6Path = "C:\temp\dotnet-hosting-6.0.26-win.exe"

try {
    Invoke-WebRequest -Uri $hostingBundle6Url -OutFile $hostingBundle6Path -UseBasicParsing
    Write-Host "Installing ASP.NET Core Hosting Bundle 6.0.26..." -ForegroundColor Yellow
    Start-Process -FilePath $hostingBundle6Path -ArgumentList "/quiet" -Wait
    Write-Host "ASP.NET Core Hosting Bundle 6.0.26 installed successfully" -ForegroundColor Green
} catch {
    Write-Host "Warning: Failed to download/install ASP.NET Core Hosting Bundle 6.0.26: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Download and install ASP.NET Core Hosting Bundle 8.0.18
Write-Host "Downloading and installing ASP.NET Core Hosting Bundle 8.0.18..." -ForegroundColor Cyan
$hostingBundle8Url = "https://download.visualstudio.microsoft.com/download/pr/d4592d88-7ae2-4528-8caf-778cde04c8e0/2b55a96fcf2d5cc3cf1ad14a17bb0a31/dotnet-hosting-8.0.18-win.exe"
$hostingBundle8Path = "C:\temp\dotnet-hosting-8.0.18-win.exe"

try {
    Invoke-WebRequest -Uri $hostingBundle8Url -OutFile $hostingBundle8Path -UseBasicParsing
    Write-Host "Installing ASP.NET Core Hosting Bundle 8.0.18..." -ForegroundColor Yellow
    Start-Process -FilePath $hostingBundle8Path -ArgumentList "/quiet" -Wait
    Write-Host "ASP.NET Core Hosting Bundle 8.0.18 installed successfully" -ForegroundColor Green
} catch {
    Write-Host "Warning: Failed to download/install ASP.NET Core Hosting Bundle 8.0.18: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Install common development tools
Write-Host "Installing Git for Windows..." -ForegroundColor Cyan
try {
    $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/Git-2.42.0.2-64-bit.exe"
    $gitPath = "C:\temp\Git-installer.exe"
    Invoke-WebRequest -Uri $gitUrl -OutFile $gitPath -UseBasicParsing
    Start-Process -FilePath $gitPath -ArgumentList "/VERYSILENT", "/NORESTART" -Wait
    Write-Host "Git installed successfully" -ForegroundColor Green
} catch {
    Write-Host "Warning: Failed to install Git: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Install Node.js (for web builds)
Write-Host "Installing Node.js..." -ForegroundColor Cyan
try {
    $nodeUrl = "https://nodejs.org/dist/v18.18.2/node-v18.18.2-x64.msi"
    $nodePath = "C:\temp\nodejs-installer.msi"
    Invoke-WebRequest -Uri $nodeUrl -OutFile $nodePath -UseBasicParsing
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $nodePath, "/quiet", "/norestart" -Wait
    Write-Host "Node.js installed successfully" -ForegroundColor Green
} catch {
    Write-Host "Warning: Failed to install Node.js: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Install PowerShell 7
Write-Host "Installing PowerShell 7..." -ForegroundColor Cyan
try {
    $ps7Url = "https://github.com/PowerShell/PowerShell/releases/download/v7.3.8/PowerShell-7.3.8-win-x64.msi"
    $ps7Path = "C:\temp\powershell7-installer.msi"
    Invoke-WebRequest -Uri $ps7Url -OutFile $ps7Path -UseBasicParsing
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $ps7Path, "/quiet", "/norestart" -Wait
    Write-Host "PowerShell 7 installed successfully" -ForegroundColor Green
} catch {
    Write-Host "Warning: Failed to install PowerShell 7: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Configure IIS application pool for ASP.NET applications
Write-Host "Configuring IIS application pool..." -ForegroundColor Cyan
try {
    Import-Module WebAdministration -ErrorAction SilentlyContinue
    if (Get-Command "New-WebAppPool" -ErrorAction SilentlyContinue) {
        if (-not (Get-WebAppPool -Name "ADOBuilds" -ErrorAction SilentlyContinue)) {
            New-WebAppPool -Name "ADOBuilds"
            Set-ItemProperty -Path "IIS:\AppPools\ADOBuilds" -Name "processModel.identityType" -Value "ApplicationPoolIdentity"
            Write-Host "Created IIS application pool for ADO builds" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "Warning: Failed to configure IIS application pool: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Create directories for ADO agent on both E: and R: drives
Write-Host "Creating directories for ADO agent..." -ForegroundColor Cyan
$adoDirectories = @(
    "E:\azagent",
    "E:\builds",
    "E:\temp",
    "E:\logs",
    "R:\builds-archive",
    "R:\artifacts",
    "R:\cache",
    "R:\workspace"
)

foreach ($dir in $adoDirectories) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force
        Write-Host "Created directory: $dir" -ForegroundColor Green
    }
}

# Set appropriate permissions on ADO directories
Write-Host "Setting permissions on ADO agent directories..." -ForegroundColor Cyan
try {
    $acl = Get-Acl "E:\azagent"
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Administrators","FullControl","ContainerInherit,ObjectInherit","None","Allow")
    $acl.SetAccessRule($accessRule)
    Set-Acl "E:\azagent" $acl
    Write-Host "Permissions set successfully on ADO agent directories" -ForegroundColor Green
} catch {
    Write-Host "Warning: Failed to set permissions: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Reset IIS to apply all changes
Write-Host "Resetting IIS to apply configuration changes..." -ForegroundColor Cyan
try {
    iisreset /noforce
    Write-Host "IIS reset completed successfully" -ForegroundColor Green
} catch {
    Write-Host "Warning: IIS reset failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "=== ADO Agent Server Configuration Completed ===" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Install Azure DevOps Agent manually or via automation" -ForegroundColor White
Write-Host "2. Configure agent with proper Azure DevOps organization URL and PAT" -ForegroundColor White
Write-Host "3. Test build capabilities" -ForegroundColor White