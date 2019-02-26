Properties `
{
    $UpsourceUrl = $env:UpsourceUrl
    $UpsourceToken = $env:UpsourceToken
    $UpsourceProject = $env:UpsourceProject
}

function SendBuildStatusToUpsource([string] $Key, [string] $jobName, [string] $JobUrl, [string] $Revision, [string] $State)
{
    $headers = @{ 'Content-Type'='application/json; charset=UTF-8'; Authorization = "Basic $UpsourceToken" }
    $body = `
        @{
            key = $Key
            name = $JobName
            state = $State
            url = $JobUrl
            project = $UpsourceProject
            revision = $Revision
        } | ConvertTo-Json

    Invoke-WebRequest "$UpsourceUrl/~buildStatus/" -Method POST -Body $body -Headers $headers -UseBasicParsing
}

function RunScriptAndUpdateUpsource([scriptblock] $Script)
{
    try
    {
        $key = $env:BUILD_ID
        $jobName = $env:JOB_NAME
        $jobUrl = $env:BUILD_URL
        $revision = $env:GIT_COMMIT

        SendBuildStatusToUpsource $key $jobName $jobUrl $revision 'in_progress'

        & $Script

        SendBuildStatusToUpsource $key $jobName $jobUrl $revision 'success'
    }
    catch
    {
        SendBuildStatusToUpsource $key $jobName $jobUrl $revision 'failed'
        throw
    }
}

Task jenkins-code-analysis -description 'Runs code analysis and updates build state in Upsource.' `
{
    RunScriptAndUpdateUpsource { Invoke-Task code-analysis }
}

Task jenkins-run-tests -description 'Runs tests and updates build state in Upsource.' `
{
    RunScriptAndUpdateUpsource { Invoke-Task run-tests }
}
