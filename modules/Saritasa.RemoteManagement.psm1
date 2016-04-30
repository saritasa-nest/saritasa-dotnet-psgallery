$credential = $null

function Set-RemoteManagementCredentials([string] $username, [string] $password, [System.Management.Automation.PSCredential] $credential)
{
    if ($username)
    {
        $script:credential = New-Object System.Management.Automation.PSCredential($username, (ConvertTo-SecureString $password -AsPlainText -Force))
    }
    else
    {
        $script:credential = $credential
    }
}

function ExecuteAppCmd([string] $serverHost, $configFilename, [string[]] $arguments)
{
    $config = Get-Content $configFilename
    $appCmd = "$env:SystemRoot\System32\inetsrv\appcmd"
    
    if ($serverHost) # Remote server.
    {
        if (!$credential)
        {
            throw 'Credentials are not set.'
        }
        
        $session = New-PSSession -UseSSL -Credential $credential $serverHost

        Invoke-Command -Session $session -ScriptBlock { $using:config | &$using:appCmd $using:arguments }

        Remove-PSSession $session
    }
    else # Local server.
    {
        Invoke-Command { $config | &$appCmd $arguments }
        $exitCode = $LASTEXITCODE
    }
    
    if ($LASTEXITCODE)
    {
        throw 'AppCmd failed.'
    }
}

function GetAppCmdOutput([string] $serverHost, [string[]] $arguments)
{
    $appCmd = "$env:SystemRoot\System32\inetsrv\appcmd"
    
    if ($serverHost) # Remote server.
    {
        if (!$credential)
        {
            throw 'Credentials are not set.'
        }
        
        $session = New-PSSession -UseSSL -Credential $credential $serverHost

        $output = Invoke-Command -Session $session -ScriptBlock { &$using:appCmd $using:arguments }

        Remove-PSSession $session
    }
    else # Local server.
    {
        $output = Invoke-Command { &$appCmd $arguments }
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
        [string] $serverHost,
        [Parameter(Mandatory = $true)]
        [string] $configFilename
    )

    ExecuteAppCmd $serverHost $configFilename @('add', 'apppool', '/in') $false
}

function Import-Sites
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $serverHost,
        [Parameter(Mandatory = $true)]
        [string] $configFilename
    )

    ExecuteAppCmd $serverHost $configFilename @('add', 'site', '/in') $false
}

function Export-AppPools
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $serverHost,
        [Parameter(Mandatory = $true)]
        [string] $outputFilename
    )
    
    $xml = GetAppCmdOutput $serverHost @('list', 'apppool', '/config', '/xml')
    $xml | Set-Content $outputFilename
}

function Export-Sites
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $serverHost,
        [Parameter(Mandatory = $true)]
        [string] $outputFilename
    )

    $xml = GetAppCmdOutput $serverHost @('list', 'site', '/config', '/xml')
    $xml | Set-Content $outputFilename
}

# Install WinRM certificate of remote server to trusted certificate root authorities store.
# Based on code by Robert Westerlund and Michael J. Lyons.
# http://stackoverflow.com/questions/22233702/how-to-download-the-ssl-certificate-from-a-website-using-powershell
function Import-WinrmCertificate
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $serverHost
    )

    if (!(IsAdmin))
    {
        throw 'Administrator permissions are required.'
    }
    
    $port = 5986
    $tempFilename = "$env:TEMP\" + [guid]::NewGuid()
    
    $webRequest = [Net.WebRequest]::Create("https://${serverHost}:$port")
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
