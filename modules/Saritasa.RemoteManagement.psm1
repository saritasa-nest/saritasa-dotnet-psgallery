$credential = $null

function Set-RemoteManagementCredentials
{
    param
    (
        [string] $Username,
        [string] $Password,
        [System.Management.Automation.PSCredential] $Credential
    )

    if ($Username)
    {
        $script:credential = New-Object System.Management.Automation.PSCredential($Username, (ConvertTo-SecureString $Password -AsPlainText -Force))
    }
    else
    {
        $script:credential = $Credential
    }
}

function ExecuteAppCmd
{
    param
    (
        [string] $ServerHost,
        [string] $ConfigFilename,
        [string[]] $Arguments
    )

    $config = Get-Content $ConfigFilename
    $appCmd = "$env:SystemRoot\System32\inetsrv\appcmd"
    
    if ($ServerHost) # Remote server.
    {
        if (!$credential)
        {
            throw 'Credentials are not set.'
        }
        
        $session = New-PSSession -UseSSL -Credential $credential $ServerHost

        Invoke-Command -Session $session -ScriptBlock { $using:config | &$using:appCmd $using:Arguments }

        Remove-PSSession $session
    }
    else # Local server.
    {
        Invoke-Command { $config | &$appCmd $Arguments }
        $exitCode = $LASTEXITCODE
    }
    
    if ($LASTEXITCODE)
    {
        throw 'AppCmd failed.'
    }
}

function GetAppCmdOutput
{
    param
    (
        [string] $ServerHost,
        [string[]] $Arguments
    )

    $appCmd = "$env:SystemRoot\System32\inetsrv\appcmd"
    
    if ($ServerHost) # Remote server.
    {
        if (!$credential)
        {
            throw 'Credentials are not set.'
        }
        
        $session = New-PSSession -UseSSL -Credential $credential $ServerHost

        $output = Invoke-Command -Session $session -ScriptBlock { &$using:appCmd $using:Arguments }

        Remove-PSSession $session
    }
    else # Local server.
    {
        $output = Invoke-Command { &$appCmd $Arguments }
    }
    
    if ($LASTEXITCODE)
    {
        throw 'AppCmd failed.'
    }
    
    $output
}

function Import-AppPools
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $ServerHost,
        [Parameter(Mandatory = $true)]
        [string] $ConfigFilename
    )

    ExecuteAppCmd $ServerHost $ConfigFilename @('add', 'apppool', '/in') $false
}

function Import-Sites
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $ServerHost,
        [Parameter(Mandatory = $true)]
        [string] $ConfigFilename
    )

    ExecuteAppCmd $ServerHost $ConfigFilename @('add', 'site', '/in') $false
}

function Export-AppPools
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $ServerHost,
        [Parameter(Mandatory = $true)]
        [string] $OutputFilename
    )
    
    $xml = GetAppCmdOutput $ServerHost @('list', 'apppool', '/config', '/xml')
    $xml | Set-Content $OutputFilename
}

function Export-Sites
{
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = 'Hostname of the server with IIS site configured.')]
        [string] $ServerHost,
        [Parameter(Mandatory = $true)]
        [string] $OutputFilename
    )

    $xml = GetAppCmdOutput $ServerHost @('list', 'site', '/config', '/xml')
    $xml | Set-Content $OutputFilename
}

<#
.SYNOPSIS
Installs WinRM certificate of remote server to trusted certificate root authorities store.

.NOTES
Based on code by Robert Westerlund and Michael J. Lyons.
http://stackoverflow.com/questions/22233702/how-to-download-the-ssl-certificate-from-a-website-using-powershell
#>
function Import-WinrmCertificate
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $ServerHost
    )

    if (!(IsAdmin))
    {
        throw 'Administrator permissions are required.'
    }
    
    $port = 5986
    $tempFilename = "$env:TEMP\" + [guid]::NewGuid()
    
    $webRequest = [Net.WebRequest]::Create("https://${ServerHost}:$port")
    try
    {
        $webRequest.GetResponse().Dispose()
    }
    catch [System.Net.WebException]
    {
        if ($_.Exception.Status -ne [System.Net.WebExceptionStatus]::TrustFailure)
        {
            # If it's not trust failure, rethrow it.
            throw
        }
    }
    
    $cert = $webRequest.ServicePoint.Certificate
    $bytes = $cert.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert)
    Set-Content -Value $bytes -Encoding Byte -Path $tempFilename

    Import-Certificate -CertStoreLocation Cert:\LocalMachine\Root $tempFilename
    Remove-Item $tempFilename
}

function IsAdmin
{
    ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
}
