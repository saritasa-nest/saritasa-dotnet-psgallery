<#PSScriptInfo

.VERSION 1.2.3

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
    $AdminUsername = $null
    $AdminPassword = $null
    $Configuration = $null
    $ServerHost = $null
    $WinrmPort = 5986
}

Import-Module Saritasa.RemoteManagement

Task init-winrm -description 'Initializes WinRM configuration.' `
{
    if ($AdminPassword)
    {
        $credential = New-Object System.Management.Automation.PSCredential($AdminUsername, (ConvertTo-SecureString $AdminPassword -AsPlainText -Force))
    }
    else
    {
        $credential = Get-Credential
    }
    Initialize-RemoteManagement -Credential $credential -Port $WinrmPort
}

Task import-sites -depends init-winrm -description 'Import app pools and sites to IIS.' `
    -requiredVariables @('Configuration', 'ServerHost') `
{  
    Import-AppPool $serverHost "$root\IIS\AppPools.${Configuration}.xml"
    Import-Site $serverHost "$root\IIS\Sites.${Configuration}.xml"
}

Task export-sites -depends init-winrm -description 'Export app pools and sites from IIS.' `
    -requiredVariables @('Configuration', 'ServerHost') `
{
    Export-AppPool $serverHost "$root\IIS\AppPools.${Configuration}.xml"
    Export-Site $serverHost "$root\IIS\Sites.${Configuration}.xml"
}

Task trust-host -depends init-winrm -description 'Add server''s certificate to trusted root CA store.' `
    -requiredVariables @('ServerHost', 'WinrmPort') `
{
    $fqdn = [System.Net.Dns]::GetHostByName($ServerHost).Hostname
    
    Import-Module Saritasa.Web
    Import-SslCertificate $fqdn $WinrmPort
    Write-Information 'SSL certificate is imported.'
       
    # Allow remote connections to the host.
    if ((Get-Item WSMan:\localhost\Client\TrustedHosts).Value -ne '*')
    {
        Set-Item WSMan:\localhost\Client\TrustedHosts $fqdn -Concatenate -Force
        Write-Information 'Host is added to trusted list.'
    }
}
