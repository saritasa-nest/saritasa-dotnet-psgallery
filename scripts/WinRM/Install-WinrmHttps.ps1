<#PSScriptInfo

.VERSION 1.1.0

.GUID 3ccd77cd-d928-4e72-98fc-82e3417f3427

.AUTHOR Anton Zimin

.COMPANYNAME Saritasa

.COPYRIGHT (c) 2016 Saritasa. All rights reserved.

.TAGS WinRM

.LICENSEURI https://raw.githubusercontent.com/dermeister0/PSGallery/master/LICENSE

.PROJECTURI https://github.com/dermeister0/PSGallery

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES

#>

<# 
.DESCRIPTION 
Generates self-signed certificate or uses existing. Configures HTTPS listener for WinRM service. Opens 5986 port in firewall. 
#> 
param
(
    [string] $CertificateThumbprint
)

trap
{
    Write-Host 'FAILURE' -BackgroundColor Red
    $_
    $host.SetShouldExit(1)
    exit
}

$hostname = $env:COMPUTERNAME

if (!$CertificateThumbprint)
{
    $CertificateThumbprint = (New-SelfSignedCertificate -DnsName $hostname -CertStoreLocation Cert:\LocalMachine\My).Thumbprint
    'New certificate is generated.'
}

New-Item -Path WSMan:\localhost\Listener -Address * -Transport HTTPS -Hostname $hostname `
    -CertificateThumbprint $CertificateThumbprint -Force

New-NetFirewallRule -DisplayName 'Windows Remote Management (HTTPS-In)' `
    -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5986
    
Write-Host "`nWinRM is set up for host $hostname." -ForegroundColor Green
