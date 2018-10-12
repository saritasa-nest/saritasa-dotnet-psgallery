$prtgUrl  = ''
$userName = ''
$password = ''
$sensors = @{}

<#
.SYNOPSIS

.EXAMPLE
Initialize-Prtg prtg.local admin Qwerty123 @{ Server1 = 10123; Server2 = 10124; }
#>
function Initialize-Prtg
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $PrtgUrl,
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,
        [Parameter(Mandatory = $true)]
        [hashtable] $Sensors
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $script:prtgUrl = $PrtgUrl
    $script:userName = $Credential.UserName
    $script:password = $Credential.GetNetworkCredential().Password
    $script:sensors = $Sensors
}

<#
.SYNOPSIS
Retrieves the sensor information by server key.

.PARAMETER Server
The server key.

.EXAMPLE
Initialize-Prtg prtg.local admin Qwerty123 @{ Server1 = 10123; Server2 = 10124; }
Get-PrtgSensorId Server1
#>
function Get-PrtgSensorId
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $Server
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $sensorId = $sensors[$Server]
    if (!$sensorId)
    {
        throw "PRTG sensor for $Server is not registered."
    }

    $sensorId
}

<#
.SYNOPSIS
Starts the PRTG sesor.

.PARAMETER Server
The server key associated with a sensor.

.EXAMPLE
Initialize-Prtg prtg.local admin Qwerty123 @{ Server1 = 10123; Server2 = 10124; }
Start-PrtgSensor Server1
#>
function Start-PrtgSensor
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $Server
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    Write-Information 'Starting PRTG sensor...'
    $sensorId = Get-PrtgSensorId($Server)
    Update-SslCheckProcedure
    $status = (Invoke-WebRequest -UseBasicParsing "$prtgUrl/api/pause.htm?id=$sensorId&action=1&pausemsg=Resumed by deployment script.&username=$username&password=$password").StatusDescription
    Write-Information "$status`n`n"
}

<#
.SYNOPSIS
Stops the PRTG sensor.

.PARAMETER Server
The server key associated with a sensor.

.EXAMPLE
Initialize-Prtg prtg.local admin Qwerty123 @{ Server1 = 10123; Server2 = 10124; }
Stop-PrtgSensor Server1
#>
function Stop-PrtgSensor
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $Server
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    Write-Information 'Stopping PRTG sensor...'
    $sensorId = Get-PrtgSensorId($Server)
    Update-SslCheckProcedure
    $status = (Invoke-WebRequest -UseBasicParsing "$prtgUrl/api/pause.htm?id=$sensorId&action=0&pausemsg=Paused by deployment script.&username=$username&password=$password").StatusDescription
    Write-Information "$status`n`n"
}
