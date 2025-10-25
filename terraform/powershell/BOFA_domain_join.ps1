# Define domain join parameters
$domainName = "CertentEMBOFA.Prod"
$ouPath = "OU=AADDC Computers,DC=CertentEMBOFA,DC=Prod"
$domainUser = "CertentEMBOFA.Prod\svc_domainjoin"
$domainPassword = ConvertTo-SecureString "So9baXdkaKvIF7FiIWvo" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($domainUser, $domainPassword)

# Join the domain and restart
try {
    Write-Host "Joining domain $domainName..." -ForegroundColor Cyan
    Add-Computer -DomainName $domainName -OUPath $ouPath -Credential $credential -Restart -Force
    Write-Host "Domain join initiated. Server will restart." -ForegroundColor Green
} catch {
    Write-Error "Failed to join domain: $_"
}
