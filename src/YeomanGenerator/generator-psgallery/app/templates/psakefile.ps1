Framework 4.6
$InformationPreference = 'Continue'
$env:PSModulePath += [IO.Path]::PathSeparator + [IO.Path]::Combine($PSScriptRoot, 'scripts', 'modules')

<% if (adminTasksEnabled || desktopEnabled || windowsServiceEnabled) { %>. .\scripts\Saritasa.AdminTasks.ps1<%= '\n' %><% } %><% if (gitTasksEnabled) { %>. .\scripts\Saritasa.GitTasks.ps1<%= '\n' %><% } %>. .\scripts\Saritasa.PsakeExtensions.ps1
. .\scripts\Saritasa.BuildTasks.ps1
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
    if ($ConfigInitialized)
    {
        return
    }
    Expand-PsakeConfiguration @{ ConfigInitialized = $true; IsLocalDevelopment = !$Environment }

    if (!$Environment)
    {
        Expand-PsakeConfiguration @{ Environment = 'Development' }
    }

    if (Test-Path '.\Config.ps1')
    {
        Import-PsakeConfigurationFile '.\Config.ps1'
    }
    else
    {
        Import-PsakeConfigurationFile ".\Config.$Environment.ps1"
        Import-PsakeConfigurationFile $SecretConfigPath
    }
}
