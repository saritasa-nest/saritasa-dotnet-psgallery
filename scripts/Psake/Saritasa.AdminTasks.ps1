<#PSScriptInfo

.VERSION 1.6.0

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
    $AdminCredential = $null # If it's not set, new credential will be assigned there.
    $AdminUsername = $null
    $AdminPassword = $null
    $Environment = $null
    $ServerHost = $null
    $SiteName = $null # Unique site name, it may include slot suffix (example.org, example.org-blue, example.org-green, example.com-001, example.com-002).
    $Slot = $null # Deployment slot (Blue, Green, 001, 002).
    $WwwrootPath = $null
    $WinrmPort = 5986
    $WinrmAuthentication = [System.Management.Automation.Runspaces.AuthenticationMechanism]::Default
}

<#
AdminCredential will be used for WinRM connection.
If it's empty, AdminUsername and AdminPassword will be converted to AdminCredential.
If AdminPassword is empty, new credential will be requested (if target server is not localhost).
#>
Task init-winrm -description 'Initializes WinRM configuration.' `
{
    if (!$AdminCredential)
    {
        if ($AdminPassword)
        {
            $credential = New-Object System.Management.Automation.PSCredential($AdminUsername, (ConvertTo-SecureString $AdminPassword -AsPlainText -Force))
        }
        elseif (!(Test-IsLocalhost $ServerHost)) # Not localhost.
        {
            $credential = Get-Credential
        }

        Expand-PsakeConfiguration @{ AdminCredential = $credential }
    }

    Initialize-RemoteManagement -Credential $AdminCredential -Port $WinrmPort -Authentication $WinrmAuthentication
}

# Use following params to import sites on localhost:
# psake import-sites -properties @{ServerHost='.';Environment='Development'}
Task import-sites -depends init-winrm -description 'Import app pools and sites to IIS.' `
    -requiredVariables @('Environment', 'ServerHost', 'SiteName', 'WwwrootPath') `
{
    $params = @{ Slot = $Slot }
    $appPoolsPath = [System.IO.Path]::GetTempFileName()
    Copy-Item "$root\IIS\AppPools.${Environment}.xml" $appPoolsPath
    Update-VariablesInFile -Path $appPoolsPath -Variables $params
    Import-AppPool $ServerHost $appPoolsPath
    Remove-Item $appPoolsPath

    $params = @{ SiteName = $SiteName; WwwrootPath = $WwwrootPath; Slot = $Slot; SiteNameHash = (GetShortHash $siteNameWithSlot); SlotHash = (GetShortHash $Slot) }
    $sitesPath = [System.IO.Path]::GetTempFileName()
    Copy-Item "$root\IIS\Sites.${Environment}.xml" $sitesPath
    Update-VariablesInFile -Path $sitesPath -Variables $params
    Import-Site $ServerHost $sitesPath
    Remove-Item $sitesPath
}

# Use following params to export sites from localhost:
# psake export-sites -properties @{ServerHost='.';Environment='Development'}
Task export-sites -depends init-winrm -description 'Export app pools and sites from IIS.' `
    -requiredVariables @('Environment', 'ServerHost') `
{
    Export-AppPool $ServerHost "$root\IIS\AppPools.${Environment}.xml"
    Export-Site $ServerHost "$root\IIS\Sites.${Environment}.xml"
}

Task trust-host -description 'Add server''s certificate to trusted root CA store.' `
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

<#
.SYNOPSIS
Returns number in 0-999 which is derived from input string hash.
#>
function GetShortHash([string] $String)
{
    $md5 = [System.Security.Cryptography.MD5CryptoServiceProvider]::new()
    $utf8 = [System.Text.Encoding]::UTF8
    $bytes = $md5.ComputeHash($utf8.GetBytes($String))

    $hash = 17
    foreach ($byte in $bytes)
    {
        $hash = $hash * 23 + $byte
    }

    $hash % 1000
}
