Properties `
{
    $Configuration = $null
<% if (webEnabled) { %>    $WebServer = $null<%= '\n' %>    $SiteName = $null<% } %>
<% if (desktopEnabled || windowsServiceEnabled) { %>    $AppServer = $null<% } %>
<% if (adminTasksEnabled || desktopEnabled || windowsServiceEnabled) { %>    $AdminUsername = $null<%= '\n' %>    $AdminPassword = $null<% } %>
<% if (webEnabled) { %>    $DeployUsername = $null<%= '\n' %>    $DeployPassword = $null<% } %>
}

$root = $PSScriptRoot
$src = Resolve-Path "$root\<%= srcPath %>"
$workspace = Resolve-Path "$root\.."

<% if (webEnabled) { %>
Task pre-publish -depends pre-build -description 'Set common publish settings for all deployments.' `
    -requiredVariables @('DeployUsername', 'DeployPassword') `
{
    $credential = New-Object System.Management.Automation.PSCredential($DeployUsername, (ConvertTo-SecureString $DeployPassword -AsPlainText -Force))
    Initialize-WebDeploy -Credential $credential
}

Task publish-web -depends pre-publish -description '* Publish all web apps to specified server.' `
    -requiredVariables @('Configuration', 'WebServer', 'SiteName') `
{
<% if (netCoreUsed) { %>
    # $packagePath = "$src\Example\Example.zip"
    # Exec { dotnet publish "$src\Example\Example.csproj" /p:PublishProfile=Package }
    # Invoke-WebDeployment -PackagePath $packagePath -ServerHost $WebServer `
    #     -SiteName $SiteName -Application ''
<% } else { %>
    # $packagePath = "$workspace\Example.zip"
    # Invoke-PackageBuild -ProjectPath "$src\Example\Example.csproj" `
    #     -PackagePath $packagePath -Configuration $Configuration
    # Invoke-WebDeployment -PackagePath $packagePath -ServerHost $WebServer `
    #     -SiteName $SiteName -Application ''
<% } // netCoreUsed %>
}
<% } // webEnabled %>
