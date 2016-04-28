$apiKey = ''

function Initialize-NewRelic([string] $apiKey)
{
    $script:apiKey = $apiKey
}

function Update-NewRelicDeployment([string] $applicationId, [string] $revision)
{
    Invoke-RestMethod -uri https://api.newrelic.com/deployments.xml -Method Post `
        -Headers @{ 'x-api-key' = $apiKey } `
        -Body @{ 'deployment[application_id]' = $applicationId; 'deployment[revision]' = $revision }
}
