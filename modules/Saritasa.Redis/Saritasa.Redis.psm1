$root = $PSScriptRoot

function Initialize-Redis
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Scope="Function", Target="*")]
    [CmdletBinding()]
    param
    (
        [string] $Host,
        [int] $Port,
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,
        [bool] $UseSsl = $true
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    
    $script:redisHost = $Host
    $script:redisPort = $Port
    $script:credential = $Credential
    $script:useSsl = $UseSsl

    $assemblyPath = Resolve-Path "$PSScriptRoot\StackExchange.Redis.dll"
    Write-Information "Loading StackExchange.Redis.dll..."
    [void][System.Reflection.Assembly]::LoadFrom($assemblyPath)
    Write-Information 'OK'
    
    $script:credentialInitialized = $true
}

function Get-Multiplexer 
{ 
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Scope="Function", Target="*")]
    [CmdletBinding()]
    param()

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if (!$credentialInitialized)
    {
        throw 'credentials not initialized'
    }

    $password = $credential.GetNetworkCredential().Password
    $mux = [StackExchange.Redis.ConnectionMultiplexer]::Connect("${redisHost}:${redisPort}, allowAdmin=true, Password=${password}, Ssl=$useSsl, abortConnect=False, ConnectTimeout=100000")

    return $mux
}

function Ping-Redis 
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Scope="Function", Target="*")]
    [CmdletBinding()]
    param()

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $mux = Get-Multiplexer

    Write-Information "Pinging redis instance"

    $endpoints = $mux.GetEndPoints()

    foreach ($endpoint in $endpoints)
    {
        Write-Information "Endpoint - $endpoint"

        $server = $mux.GetServer($endpoint)

        $result = $server.Ping()

        Write-Information "${result} at endpoint $endpoint"
    }

    $mux.Dispose()
}


function Invoke-FlushRedis 
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Scope="Function", Target="*")]
    [CmdletBinding()]
    param()

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $mux = Get-Multiplexer

    Write-Information "Flushing redis instance"

    $endpoints = $mux.GetEndPoints()

    foreach ($endpoint in $endpoints)
    {
        Write-Information "Endpoint - $endpoint"

        $server = $mux.GetServer($endpoint, $null)

        Write-Information "Flushing database at endpoint - $endpoint"

        $result = $server.FlushDatabase(0, 0)

        Write-Information "Database flushed at endpoint - $endpoint"
    }

    $mux.Dispose()
}
