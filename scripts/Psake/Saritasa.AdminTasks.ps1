<#PSScriptInfo

.VERSION 1.0.0

.GUID 6d562cb9-4323-4944-bb81-eba9b99b8b21

.AUTHOR Anton Zimin

.COMPANYNAME Saritasa

.COPYRIGHT (c) 2016 Saritasa. All rights reserved.

.TAGS WinRM WSMan

.LICENSEURI https://raw.githubusercontent.com/Saritasa/PSGallery/master/LICENSE

.PROJECTURI https://github.com/Saritasa/PSGallery

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES

.SYNOPSIS
Contains Psake tasks for remote server administration.

.DESCRIPTION

#>

Properties `
{
    $serverHost = $null
    $winrmPort = $null
}

Task trust-host -description 'Add server''s certificate to trusted root CA store.' `
    -requiredVariables @('serverHost', 'winrmPort') `
{
    $fqdn = [System.Net.Dns]::GetHostByName($serverHost).Hostname
    
    Import-Module "$root\Saritasa.Web.psd1"
    Import-SslCertificate $fqdn $winrmPort
    Write-Information 'SSL certificate is imported.'
       
    # Allow remote connections to the host.
    if ((Get-Item WSMan:\localhost\Client\TrustedHosts).Value -ne '*')
    {
        Set-Item WSMan:\localhost\Client\TrustedHosts $fqdn -Concatenate -Force
        Write-Information 'Host is added to trusted list.'
    }
}
