Framework 4.6
$InformationPreference = 'Continue'
$env:PSModulePath += ";$PSScriptRoot\scripts\modules"

<% if (adminTasksEnabled) { %>. .\scripts\Saritasa.AdminTasks.ps1<%= '\n' %><% } %>. .\scripts\Saritasa.PsakeTasks.ps1

Properties `
{

}
