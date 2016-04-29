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

function ExecuteAppCmd($serverHost, $configFilename, [string[]] $arguments)
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

function GetAppCmdOutput($serverHost, [string[]] $arguments)
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

function Import-AppPools($serverHost, $configFilename)
{
    ExecuteAppCmd $serverHost $configFilename @('add', 'apppool', '/in') $false
}

function Import-Sites($serverHost, $configFilename)
{
    ExecuteAppCmd $serverHost $configFilename @('add', 'site', '/in') $false
}

function Export-AppPools($serverHost, $outputFilename)
{
    $xml = GetAppCmdOutput $serverHost @('list', 'apppool', '/config', '/xml')
    $xml | Set-Content $outputFilename
}

function Export-Sites($serverHost, $outputFilename)
{
    $xml = GetAppCmdOutput $serverHost @('list', 'site', '/config', '/xml')
    $xml | Set-Content $outputFilename
}
