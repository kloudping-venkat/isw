$stagingDir = "C:\TEMP"

#AppTier Roles and Features:
[array]$AppFeatures = @("FileAndStorage-Services", "File-Services", "FS-FileServer", "Storage-Services", "Web-Server", "Web-WebServer", "Web-Common-Http", "Web-Default-Doc", "Web-Security", "Web-Filtering", "Web-App-Dev", "Web-Net-Ext", "Web-Mgmt-Tools", "Web-Mgmt-Console", "Web-Scripting-Tools", "Web-Mgmt-Service", "NET-Framework-Features", "NET-Framework-Core", "NET-HTTP-Activation", "NET-Non-HTTP-Activ", "NET-Framework-45-Features", "NET-Framework-45-Core", "NET-Framework-45-ASPNET", "NET-WCF-Services45", "NET-WCF-TCP-PortSharing45", "RSAT", "RSAT-SNMP", "SNMP-Service", "SNMP-WMI-Provider", "Telnet-Client", "PowerShellRoot", "WAS", "WAS-Process-Model", "WAS-NET-Environment", "WAS-Config-APIs", "WoW64-Support")
#DotNet Core Install:
$WebDotNetInst = "https://usngdevenvaddons.blob.core.windows.net/quarter1/dotnet-hosting-6.0.26-win.exe?sp=r&st=2025-01-31T15:23:39Z&se=2026-01-30T23:23:39Z&spr=https&sv=2022-11-02&sr=b&sig=SVI24yx5bxIMtrEx%2B1EtuIUXpkYKvnTpU%2F1GWwamTXE%3D"
$DotNet8Inst = "https://download.microsoft.com/download/6/0/f/60fc8c9e-b3b5-4c4b-89b5-82e2cd2abcd7/dotnet-hosting-8.0.18-win.exe"

foreach ($AppFeature in $AppFeatures) {
    Add-WindowsFeature -Name $AppFeature -IncludeManagementTools
    Write-Host "Attempting install of $AppFeature .... "
}

Set-Location -Path $stagingDir

# Install ASP.NET Core 6.0.26 Hosting Bundle
Write-Host "Installing ASP.NET Core 6.0.26 Hosting Bundle..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $WebDotNetInst -OutFile "dotnet-hosting-6.0.26-win.exe"
Start-Sleep -Seconds 3
Start-Process -FilePath "$stagingDir\dotnet-hosting-6.0.26-win.exe" -ArgumentList "/quiet", "/norestart" -Wait -PassThru
Write-Host "ASP.NET Core 6.0.26 installation completed." -ForegroundColor Green

# Install ASP.NET Core 8.0.18 Hosting Bundle
Write-Host "Installing ASP.NET Core 8.0.18 Hosting Bundle..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $DotNet8Inst -OutFile "dotnet-hosting-8.0.18-win.exe"
Start-Sleep -Seconds 3
Start-Process -FilePath "$stagingDir\dotnet-hosting-8.0.18-win.exe" -ArgumentList "/quiet", "/norestart" -Wait -PassThru
Write-Host "ASP.NET Core 8.0.18 installation completed." -ForegroundColor Green

# Add DevOps group to local administrators
Write-Host "Adding DevOps group to local administrators..." -ForegroundColor Cyan
try {
    Add-LocalGroupMember -Group "Administrators" -Member "CertentEMBOFA.Prod\BOFAProd_DevOps"
    Write-Host "Successfully added BOFAProd_DevOps to local administrators." -ForegroundColor Green
} catch {
    Write-Warning "Failed to add DevOps group to local administrators: $_"
}