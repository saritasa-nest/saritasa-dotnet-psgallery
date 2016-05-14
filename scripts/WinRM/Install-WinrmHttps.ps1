<#PSScriptInfo

.VERSION 1.3.1

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
.SYNOPSIS
Configures server to accept WinRM connections over HTTPS.

.DESCRIPTION
Generates self-signed certificate or uses existing. Configures HTTPS listener for WinRM service. Opens 5986 port in firewall.

For Windows Server 2008 you should execute following statement to disable remote UAC:
Set-ItemProperty –Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System –Name LocalAccountTokenFilterPolicy –Value 1 –Type DWord
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
    $existingCertificate = Get-ChildItem -Path Cert:\LocalMachine\My | where { $_.Subject -EQ "CN=$hostname" } | select -First 1
    if ($existingCertificate)
    {
        $CertificateThumbprint = $existingCertificate.Thumbprint
        Write-Host 'Using existing certificate...'
    }
    else
    {
        $CertificateThumbprint = (New-SelfSignedCertificate -DnsName $hostname -CertStoreLocation Cert:\LocalMachine\My).Thumbprint
        Write-Host 'New certificate is generated.'
    }
}

$existingListener = Get-ChildItem WSMan:\localhost\Listener | ? { $_.Keys[0] -eq 'Transport=HTTPS' }

if (!$existingListener)
{
    New-Item -Path WSMan:\localhost\Listener -Address * -Transport HTTPS -Hostname $hostname `
        -CertificateThumbprint $CertificateThumbprint -Force
    Write-Host 'New listener is created.'
}
else
{
    Write-Host 'Listener already exists.'
}

try
{
    New-NetFirewallRule -DisplayName 'Windows Remote Management (HTTPS-In)' `
        -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5986 -ErrorAction Stop
    Write-Host 'Firewall rule is updated.'
}
catch [Microsoft.Management.Infrastructure.CimException]
{
    if ($_.Exception.HResult -eq 0x80131500)
    {
        Write-Host 'Windows Firewall is not enabled.'
    }
    else
    {
        throw
    }
}

Write-Host "`nWinRM is set up for host $hostname." -ForegroundColor Green
