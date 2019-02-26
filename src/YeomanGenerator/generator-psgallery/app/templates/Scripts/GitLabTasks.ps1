<% if (upsourceUsed) { %>
Properties `
{
    $UpsourceUrl = $env:UpsourceUrl
    $UpsourceToken = $env:UpsourceToken
    $UpsourceProject = $env:UpsourceProject
}
<% } %>
Task gitlab-checkout -description 'Checks out to a local branch.' `
{
    $tag = $env:CI_COMMIT_TAG
    $branch = $null

    if ($tag)
    {
        $branches = Exec { git branch -r  --format="%(refname:short)" --contains $tag }
        if (($branches | Select-String '^origin/master$').Length -eq 1)
        {
            $branch = 'master'
        }
        else
        {
            throw "Unexpected tag: $tag"
        }
    }
    else
    {
        $branch = $env:CI_COMMIT_REF_NAME
    }

    Exec { git checkout -B $branch $env:CI_COMMIT_SHA }
}
<% if (upsourceUsed) { %>
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
        $key = $env:CI_JOB_ID
        $jobName = $env:CI_JOB_NAME
        $jobUrl = $env:CI_JOB_URL
        $revision = $env:CI_COMMIT_SHA

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

Task gitlab-code-analysis -description 'Runs code analysis and updates build state in Upsource.' `
{
    RunScriptAndUpdateUpsource { Invoke-Task code-analysis }
}

Task gitlab-run-tests -description 'Runs tests and updates build state in Upsource.' `
{
    RunScriptAndUpdateUpsource { Invoke-Task run-tests }
}
<% } %>