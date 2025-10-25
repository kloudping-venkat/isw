New-Item -Path "HKLM:\SOFTWARE\Wow6432Node\Tanium\Tanium Client\Sensor Data" -Name "Tags" -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Tanium\Tanium Client\Sensor Data\Tags" -Name "Certent-EM"
 
#Verify Tanium is not running
$ProcessCheck = (Get-Process -Name TaniumClient -ErrorAction SilentlyContinue -ErrorVariable ProcessError)
if($null -ne $ProcessCheck) {Exit 2}
#Verify Working Directories Exist
$WorkingDIR = "C:\Temp\Tanium\windows-client-bundle"
if(!(Test-Path -Path $WorkingDIR )){
    New-Item -ItemType directory -Path $WorkingDIR
    }
# Source file location
$source = 'https://downloads.it.insightsoftware.com/misc/Tanium/windows-client-bundle.zip'
# Destination to save the file
$destination = 'C:\Temp\Tanium\windows-client-bundle.zip'
#Download the file
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $source -OutFile $destination
Start-Sleep 60
#Unzip the Package
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory("C:\Temp\Tanium\windows-client-bundle.zip", "C:\Temp\Tanium\windows-client-bundle")
#Install Tanium agent
Set-Location "C:\Temp\Tanium\windows-client-bundle"
.\SetupClient.exe /KeyPath="C:\Temp\Tanium\windows-client-bundle\tanium-init.dat" /S
 
Start-Sleep -Seconds 360
 
Exit 0