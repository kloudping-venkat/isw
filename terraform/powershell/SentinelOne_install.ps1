#Variable Declaration
$stagingDir = "C:\TEMP"
$S1Install = "https://usngdevenvaddons.blob.core.windows.net/quarter1/SentinelOneInstaller_windows_64bit_v24_1_5_277.exe?sp=r&st=2025-05-14T11:22:06Z&se=2026-05-14T19:22:06Z&spr=https&sv=2024-11-04&sr=b&sig=KE2RuNGwiDo8RMLcgwMS1W%2FqvtFPCGAESJgkWjW9Agk%3D"
$S1SiteToken = "eyJ1cmwiOiAiaHR0cHM6Ly91c2VhMS1pbnNvZi5zZW50aW5lbG9uZS5uZXQiLCAic2l0ZV9rZXkiOiAiMmM3NTczZDE0MzBmZjk4NiJ9"

# ----- SentinelOne Install Section -----
Write-Host "Installing SentinelOne Agent" -ForegroundColor Blue -BackgroundColor White

Set-Location -Path $stagingDir 
Invoke-WebRequest -Uri $S1Install -OutFile "SentinelOneInstaller.exe" -UseBasicParsing

$S1Local = "$stagingDir\SentinelOneInstaller.exe"

#Wait until the file is present
while (-not (Test-Path $S1Local)) {
    Write-Host "SentinelOne Setup not found, waiting..."
    Start-Sleep -Seconds 2  # Adjust the wait time as needed
}
# Once the file is present, run your code here
Write-Host "SentinelOne Setup is found, running the rest of the script" -ForegroundColor Blue -BackgroundColor White
# Run the Installer
& $S1Local /q /SITE_TOKEN="$S1SiteToken"
Start-Process -FilePath "$S1Local" -ArgumentList "-q -a WSC=false -t $S1SiteToken"  
Write-Host "SentinelOne Installation/Config Complete, please review any errors and restart when ready" -ForegroundColor Blue -BackgroundColor White
