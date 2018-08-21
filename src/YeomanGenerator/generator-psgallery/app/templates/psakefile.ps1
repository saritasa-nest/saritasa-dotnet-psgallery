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

    if (!$InformationalVersion)
    {
        # 1.2.3+Branch.master.Sha.dc6ebc32aa8ecf20529a677d896a8263df4900ee
        Expand-PsakeConfiguration @{ InformationalVersion = Exec { GitVersion.exe /showvariable InformationalVersion } }
    }

    if (!$MajorMinorPatch)
    {
        # 1.2.3
        Expand-PsakeConfiguration @{ MajorMinorPatch = Exec { GitVersion.exe /showvariable MajorMinorPatch } }
    }
}
