<% if (vaultEnabled) { %>
# $env:VAULT_ADDR and $env:VAULT_TOKEN should be set.
$secretPath = 'secret/project-development'<% } %>

Expand-PsakeConfiguration `
@{
    Configuration = 'Debug'
<% if (webEnabled) { %>    WebServer = 'localhost'
    SiteName = 'example.com'
    DeployUsername = 'undefined'
    DeployPassword = 'undefined'
    WwwrootPath = 'C:\inetpub\wwwroot'<% } %>
<% if (desktopEnabled || windowsServiceEnabled) { %>    AppServer = 'localhost'
    ApprootPath = 'C:\approot'<% } %>
<% if (adminTasksEnabled || desktopEnabled || windowsServiceEnabled) { %>    AdminUsername = 'Administrator'
    AdminPassword = 'secret'<% } %>
<% if (windowsServiceEnabled) { %>    ServiceUsername = 'Administrator'
    ServicePassword = 'secret'<% } %>
<% if (webEnabled || windowsServiceEnabled) { %>
    DatabaseServer = '.\SQLEXPRESS'
    DatabaseUsername = 'sa'
    DatabasePassword = '123'
<% } %>
}

<% if (vaultEnabled) { %>
if (!$IsLocalDevelopment -or $env:VAULT_ADDR)
{
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 'Tls12'
    $vault = Get-Vault
    $data = Get-Secret $vault $secretPath
    $configuration = @{}
    $data.PSObject.Properties | ForEach-Object { $configuration[$_.Name] = $_.Value }

    Expand-PsakeConfiguration $configuration
}<% } %>
