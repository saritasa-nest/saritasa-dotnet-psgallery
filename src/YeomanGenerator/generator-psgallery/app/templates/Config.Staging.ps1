<% if (vaultEnabled) { %>
# $env:VAULT_ADDR and $env:VAULT_TOKEN should be set.
$secretPath = 'secret/project-staging'<% } %>

Expand-PsakeConfiguration `
@{
    Configuration = 'Release'
<% if (webEnabled) { %>    WebServer = 'web.example.com'
    SiteName = 'example.com'
    DeployUsername = $env:DeployUsername
    DeployPassword = $env:DeployPassword
    WwwrootPath = 'C:\inetpub\wwwroot'<% } %>
<% if (desktopEnabled || windowsServiceEnabled) { %>    AppServer = 'app.example.com'
    ApprootPath = 'C:\approot'<% } %>
<% if (adminTasksEnabled || desktopEnabled || windowsServiceEnabled) { %>    AdminUsername = $env:AdminUsername
    AdminPassword = $env:AdminPassword<% } %>
<% if (windowsServiceEnabled) { %>    ServiceUsername = $env:ServiceUsername
    ServicePassword = $env:ServicePassword<% } %>
<% if (webEnabled || windowsServiceEnabled) { %>
    DatabaseServer = 'mssql.example.com'
    DatabaseUsername = $env:DatabaseUser
    DatabasePassword = $env:DatabasePassword<% } %>
}

<% if (vaultEnabled) { %>
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 'Tls12'
$vault = Get-Vault
$data = Get-Secret $vault $secretPath
$configuration = @{}
$data.PSObject.Properties | ForEach-Object { $configuration[$_.Name] = $_.Value }

Expand-PsakeConfiguration $configuration<% } %>
