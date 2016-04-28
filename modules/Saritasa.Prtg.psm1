$prtgUrl  = ''
$userName = ''
$password = ''
$sensors = @{}

# $sensors:
# @{ Server1 = 10123; Server2 = 10124; }
function Initialize-Prtg([string] $prtgUrl, [string] $userName, [string] $password, [hashtable] $sensors)
{
    $script:prtgUrl = $prtgUrl
    $script:userName = $userName
    $script:password = $password
    $script:sensors = $sensors
}

function Get-SensorId([string] $server)
{
    $sensorId = $sensors[$server]
    if (!$sensorId)
    {
        throw "PRTG sensor for $server is not registered."
    }
    
    $sensorId
}

function Start-Sensor([string] $server)
{
    'Starting PRTG sensor...'
    $sensorId = Get-SensorId($server)
    Update-SslCheckProcedure
    $status = (Invoke-WebRequest "$prtgUrl/api/pause.htm?id=$sensorId&action=1&pausemsg=Resumed by deployment script.&username=$username&password=$password").StatusDescription
    "$status`n`n"
}

function Stop-Sensor([string] $server)
{
    'Stopping PRTG sensor...'
    $sensorId = Get-SensorId($server)
    Update-SslCheckProcedure
    $status = (Invoke-WebRequest "$prtgUrl/api/pause.htm?id=$sensorId&action=0&pausemsg=Paused by deployment script.&username=$username&password=$password").StatusDescription
    "$status`n`n"
}
