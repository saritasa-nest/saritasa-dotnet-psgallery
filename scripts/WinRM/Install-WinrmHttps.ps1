<#PSScriptInfo

.VERSION 1.6.4

.GUID 3ccd77cd-d928-4e72-98fc-82e3417f3427

.AUTHOR Anton Zimin

.COMPANYNAME Saritasa

.COPYRIGHT (c) 2016 Saritasa. All rights reserved.

.TAGS WinRM

.LICENSEURI https://raw.githubusercontent.com/Saritasa/PSGallery/master/LICENSE

.PROJECTURI https://github.com/Saritasa/PSGallery

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

[CmdletBinding()]
param
(
    [string] $CertificateThumbprint,
    [switch] $Force
)

if (!$PSBoundParameters.ContainsKey('InformationAction'))
{
    $InformationPreference = 'Continue'
}

trap
{
    Write-Error 'FAILURE'
    $_
    exit
}


function FindCertificate
{
    param
    (
        [string] $Hostname
    )
    
    Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Subject -EQ "CN=$Hostname" } | Select-Object -First 1
}

function GenerateCertificate
{
    param
    (
        [string] $Hostname
    )

    $cmd = Get-Command New-SelfSignedCertificate -ErrorAction Ignore
    if ($cmd)
    {
        $certificateThumbprint = (New-SelfSignedCertificate -DnsName $hostname -CertStoreLocation Cert:\LocalMachine\My).Thumbprint
    }
    else # Windows Server 2008, 2008 R2
    {
        $scriptPath = "$env:TEMP\New-SelfSignedCertificateEx.ps1"
        Invoke-WebRequest 'https://raw.githubusercontent.com/Saritasa/PSGallery/master/scripts/WinRM/New-SelfSignedCertificateEx.ps1' -OutFile $scriptPath
        . $scriptPath
        Remove-Item $scriptPath | Out-Null

        $pfxFile = "$Hostname.pfx"
        $password = 'pwd'

        New-SelfSignedCertificateEx -Subject "CN=$Hostname" `
            -Exportable -Password (ConvertTo-SecureString $password -AsPlainText -Force) -Path $pfxFile `
            -KeyUsage 'DataEncipherment', 'KeyEncipherment', 'DigitalSignature' -EnhancedKeyUsage 'Server Authentication' | Out-Null

        certutil -p $password -importpfx $pfxFile | Out-Null
        if ($LASTEXITCODE)
        {
            throw 'CertUtil failed.'
        }

        Remove-Item $pfxFile | Out-Null

        $existingCertificate = FindCertificate $Hostname
        if ($existingCertificate)
        {
            $certificateThumbprint = $existingCertificate.Thumbprint
        }
        else
        {
            throw 'New certificate is not found.'
        }
    }

    $certificateThumbprint
}


$hostname = [System.Net.Dns]::GetHostByName('localhost').Hostname

if (!$CertificateThumbprint)
{
    $existingCertificate = FindCertificate $hostname
    if ($existingCertificate)
    {
        $CertificateThumbprint = $existingCertificate.Thumbprint
        Write-Information 'Using existing certificate...'
    }
    else
    {
        $CertificateThumbprint = GenerateCertificate $hostname
        Write-Information 'New certificate is generated.'
    }
}

$existingListener = Get-ChildItem WSMan:\localhost\Listener |
    Where-Object { $_.Keys[0] -eq 'Transport=HTTPS' }

if ($existingListener)
{
    Write-Information 'Listener already exists.'
    if ($Force)
    {
        Write-Information 'Reinstalling...'
        Remove-Item "WSMan:\localhost\Listener\$($existingListener.Name)" -Recurse
        $existingListener = $null
    }
}

if (!$existingListener)
{
    New-Item -Path WSMan:\localhost\Listener -Address * -Transport HTTPS -Hostname $hostname `
        -CertificateThumbprint $CertificateThumbprint -Force
    Write-Information 'New listener is created.'
}

try
{
    $cmd = Get-Command New-NetFirewallRule -ErrorAction Ignore
    $ruleName = 'Windows Remote Management (HTTPS-In)'
    $port = 5986

    if ($cmd)
    {
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $port -ErrorAction Stop
    }
    else
    {
        netsh advfirewall firewall add rule name=$ruleName protocol=TCP dir=in localport=$port action=allow
        if ($LASTEXITCODE)
        {
            throw 'Netsh failed.'
        }
    }

    Write-Information 'Firewall rule is updated.'
}
catch [Microsoft.Management.Infrastructure.CimException]
{
    if ($_.Exception.HResult -eq 0x80131500)
    {
        Write-Information 'Windows Firewall is not enabled.'
    }
    else
    {
        throw
    }
}

Write-Information "`nWinRM is set up for host $hostname."
