Expand-PsakeConfiguration `
@{
    Configuration = 'Release'
    <% if (webEnabled) { %>
    WebServer = 'app.example.com'
    SiteName = 'example.com'
    DeployUsername = $env:DeployUsername
    DeployPassword = $env:DeployPassword
    WwwrootPath = 'C:\inetpub\wwwroot'
    <% } %>
    <% if (desktopEnabled || windowsServiceEnabled) { %>
    AppServer = 'app.example.com'
    ApprootPath = 'C:\approot'
    <% } %>
    <% if (adminTasksEnabled || desktopEnabled || windowsServiceEnabled) { %>
    AdminUsername = $env:AdminUsername
    AdminPassword = $env:AdminPassword
    <% } %>
}