Framework 4.6
$InformationPreference = 'Continue'
$env:PSModulePath += ";$PSScriptRoot\scripts\modules"

<% if (adminTasksEnabled) { %>. .\scripts\Saritasa.AdminTasks.ps1<%= '\n' %><% } %><% if (gitTasksEnabled) { %>. .\scripts\Saritasa.GitTasks.ps1<%= '\n' %><% } %>. .\scripts\Saritasa.PsakeExtensions.ps1
. .\scripts\Saritasa.PsakeTasks.ps1

. .\scripts\BuildTasks.ps1
. .\scripts\PublishTasks.ps1

Properties `
{
<% if (adminTasksEnabled || desktopEnabled || windowsServiceEnabled) { %>    $AdminUsername = $env:AdminUsername<%= '\n' %>    $AdminPassword = $env:AdminPassword<% } %>
<% if (webEnabled) { %>    $DeployUsername = $env:DeployUsername<%= '\n' %>    $DeployPassword = $env:DeployPassword<%= '\n' %><% } %>
    $Environment = $env:Environment
    $SecretConfigPath = $env:SecretConfigPath
<% if (webEnabled) { %>    $SiteName = 'example.com'<%= '\n' %>    $WwwrootPath = 'C:\inetpub\wwwroot'<% } %>
<% if (desktopEnabled || windowsServiceEnabled) { %>    $ApprootPath = 'C:\approot'<% } %>
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
