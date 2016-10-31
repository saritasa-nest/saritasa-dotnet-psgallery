Framework 4.6
$InformationPreference = 'Continue'
$env:PSModulePath += ";$PSScriptRoot\scripts\modules"

<% if (adminTasksEnabled) { %>. .\scripts\Saritasa.AdminTasks.ps1<%= '\n' %><% } %>. .\scripts\Saritasa.PsakeTasks.ps1
. .\scripts\BuildTasks.ps1
. .\scripts\PublishTasks.ps1

Properties `
{
<% if (adminTasksEnabled || desktopEnabled || windowsServiceEnabled) { %>    $AdminUsername = $env:AdminUsername<%= '\n' %>    $AdminPassword = $env:AdminPassword<% } %>
<% if (webEnabled) { %>    $DeployUsername = $env:DeployUsername<%= '\n' %>    $DeployPassword = $env:DeployPassword<%= '\n' %><% } %>
    $Configuration = 'Debug'
<% if (webEnabled) { %>    $SiteName = 'example.com'<%= '\n' %>    $WwwrootPath = 'C:\inetpub\wwwroot'<% } %>
<% if (desktopEnabled || windowsServiceEnabled) { %>    $ApprootPath = 'C:\approot'<% } %>
}
