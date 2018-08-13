Framework 4.6
$InformationPreference = 'Continue'
$env:PSModulePath += ";$PSScriptRoot\scripts\modules"

<% if (adminTasksEnabled) { %>. .\scripts\Saritasa.AdminTasks.ps1<%= '\n' %><% } %><% if (gitTasksEnabled) { %>. .\scripts\Saritasa.GitTasks.ps1<%= '\n' %><% } %>. .\scripts\Saritasa.PsakeExtensions.ps1
. .\scripts\Saritasa.PsakeTasks.ps1

. .\scripts\BuildTasks.ps1
. .\scripts\PublishTasks.ps1

Properties `
{
    $Environment = $env:Environment
    $SecretConfigPath = $env:SecretConfigPath
}

TaskSetup `
{
    if (!$Environment)
    {
        Expand-PsakeConfiguration @{ Environment = 'Development' }
    }
    Import-PsakeConfigurationFile ".\Config.$Environment.ps1"
    Import-PsakeConfigurationFile $SecretConfigPath
}
