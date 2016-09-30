$apiKey = ''

function Initialize-NewRelic
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $ApiKey
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $script:apiKey = $ApiKey
}

function Update-NewRelicDeployment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $ApplicationId,
        [Parameter(Mandatory = $true)]
        [string] $Revision
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    Invoke-RestMethod -uri https://api.newrelic.com/deployments.xml -Method Post `
        -Headers @{ 'x-api-key' = $apiKey } `
        -Body @{ 'deployment[application_id]' = $ApplicationId; 'deployment[revision]' = $Revision }
}
