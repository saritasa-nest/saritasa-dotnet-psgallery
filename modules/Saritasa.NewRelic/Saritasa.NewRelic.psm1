$apiKey = ''

<#
.SYNOPSIS
Initialize New Relic interactions.

.PARAMETER ApiKey
Your API key used to access the New Relic.

.NOTES
Read more about how to generate an API key: https://docs.newrelic.com/docs/apis/rest-api-v2/requirements/api-keys#rest-api
#>
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

<#
.SYNOPSIS
Notifies New Relic about a new deployment.

.EXAMPLE
Initialize-NewRelic $env:NewRelicApiKey
Update-NewRelicDeployment 'aaabbbccc123' '1.1.2'

Notifies New Relic about a new deployment with key name '1.1.2' for the 'aaabbbccc123' application.

.NOTES
Initialize-NewRelic cmdlet should be called prior to this cmdlet.
#>
function Update-NewRelicDeployment
{
    [CmdletBinding()]
    param
    (
        # Application Id in New Relic to update.
        [Parameter(Mandatory = $true)]
        [string] $ApplicationId,
        # Unique ID of current deployment.
        # Can be any string, but usually is a version number or Git commit checksum.
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, 127)]
        [string] $Revision
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    Invoke-RestMethod -uri https://api.newrelic.com/deployments.xml -Method Post `
        -Headers @{ 'x-api-key' = $apiKey } `
        -Body @{ 'deployment[application_id]' = $ApplicationId; 'deployment[revision]' = $Revision }
}
