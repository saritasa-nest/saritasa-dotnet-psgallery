<#
.SYNOPSIS
Configure some basic Redis parameters.

.EXAMPLE
$password = "123" | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential "username", $password
Initialize-Redis myredis.host.com -Port 1433 -Credential $credential

.NOTES
StackExchange.Redis.dll file should be located in the same directory with this script.
#>
function Initialize-Redis
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Scope="Function", Target="*")]
    [CmdletBinding()]
    param
    (
        # Redis hostname.
        [string] $Host,
        # Redis port.
        [int] $Port,
        # Credential containing password to Redis.
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,
        # Whether or not to use secure connection.
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

<#
.SYNOPSIS
Get a connection multiplexer from configured Redis parameters
#>
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
    [StackExchange.Redis.ConnectionMultiplexer]::Connect("${redisHost}:${redisPort}, allowAdmin=true, Password=${password}, Ssl=$useSsl, abortConnect=False, ConnectTimeout=100000")
}

<#
.SYNOPSIS
Pings the Redis instance.
#>
function Ping-Redis
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Scope="Function", Target="*")]
    [CmdletBinding()]
    param()

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $mux = Get-Multiplexer
    Use-Object $mux `
    {
        Write-Information "Pinging redis instance"

        $endpoints = $mux.GetEndPoints()

        foreach ($endpoint in $endpoints)
        {
            Write-Information "Endpoint - $endpoint"

            $server = $mux.GetServer($endpoint)

            $result = $server.Ping()

            Write-Information "${result} at endpoint $endpoint"
        }
    }
}

<#
.SYNOPSIS
Delete all the keys of the Redis database.

.NOTES
For more info, see http://redis.io/commands/flushdb
#>
function Invoke-FlushRedis
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Scope="Function", Target="*")]
    [CmdletBinding()]
    param()

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $mux = Get-Multiplexer
    Use-Object $mux `
    {
        Write-Information "Flushing redis instance"

        $endpoints = $mux.GetEndPoints()

        foreach ($endpoint in $endpoints)
        {
            Write-Information "Endpoint - $endpoint"

            $server = $mux.GetServer($endpoint, $null)

            Write-Information "Flushing database at endpoint - $endpoint"

            $server.FlushDatabase(0, 0)

            Write-Information "Database flushed at endpoint - $endpoint"
        }
    }
}
