Expand-PsakeConfiguration `
@{
    Configuration = 'Release'
    <% if (webEnabled) { %>
    WebServer = 'app.example.com'
    SiteName = 'example.com'
    DeployUsername = $env:DeployUsername
    DeployPassword = $env:DeployPassword
    <% } %>
    <% if (desktopEnabled || windowsServiceEnabled) { %>
    AppServer = 'app.example.com'
    <% } %>
    <% if (adminTasksEnabled || desktopEnabled || windowsServiceEnabled) { %>
    AdminUsername = $env:AdminUsername
    AdminPassword = $env:AdminPassword
    <% } %>
}