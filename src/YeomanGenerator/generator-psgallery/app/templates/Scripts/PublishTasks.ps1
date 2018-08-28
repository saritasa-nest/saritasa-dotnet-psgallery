Properties `
{
    $Configuration = $null
<% if (webEnabled) { %>    $WebServer = $null<%= '\n' %>    $SiteName = $null<% } %>
<% if (desktopEnabled || windowsServiceEnabled) { %>    $AppServer = $null<% } %>
<% if (adminTasksEnabled || desktopEnabled || windowsServiceEnabled) { %>    $AdminUsername = $null<%= '\n' %>    $AdminPassword = $null<% } %>
<% if (webEnabled) { %>    $DeployUsername = $null<%= '\n' %>    $DeployPassword = $null<% } %>
<% if (windowsServiceEnabled) { %>    $ServiceUsername = $null<%= '\n' %>    $ServicePassword = $null<%}%>
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
    # TODO: Fix project name.
    $projectName = 'Example.Web'
    $packagePath = "$src\$projectName\$projectName.zip"
    Copy-Item "$src\$projectName\web.config.template" "$src\$projectName\web.config"
    Update-VariablesInFile -Path "$src\$projectName\web.config" -Variables @{ Environment = $Environment }
    Exec { dotnet publish -c $Configuration "$src\$projectName\$projectName.csproj" /p:PublishProfile=Package }
    Invoke-WebDeployment -PackagePath $packagePath -ServerHost $WebServer `
        -SiteName $SiteName -Application '' -MSDeployParams @('-enablerule:AppOffline')
<% } else { %>
    $buildParams = @("/p:Environment=$Environment")

    # TODO: Fix project name.
    $projectName = 'Example.Web'
    $packagePath = "$workspace\$projectName.zip"
    Invoke-PackageBuild -ProjectPath "$src\$projectName\$projectName.csproj" `
        -PackagePath $packagePath -Configuration $Configuration -BuildParams $buildParams
    Invoke-WebDeployment -PackagePath $packagePath -ServerHost $WebServer `
        -SiteName $SiteName -Application ''
<% } // netCoreUsed %>
}
<% } // webEnabled %>
<% if (desktopEnabled) { %>
Task publish-app -depends build, init-winrm -description '* Publish desktop project to specified server.' ` `
    -requiredVariables @('Configuration', 'AppServer', 'ApprootPath') `
{
    $session = Start-RemoteSession -ServerHost $AppServer
    # TODO: Fix project name.
    $projectName = 'Example.App'
    $destinationPath = "$ApprootPath\$projectName"

    Invoke-DesktopProjectDeployment -Session $session `
        -BinPath "$src\$projectName\bin\$Configuration" `
        -DestinationPath $destinationPath `
        -BeforeDeploy { } -AfterDeploy { }

    Remove-PSSession $session
}
<% } // desktopEnabled %>
<% if (windowsServiceEnabled) { %>
Task publish-service -depends build, init-winrm -description '* Publish service to specified server.' ` `
    -requiredVariables @('Configuration', 'AppServer', 'ApprootPath',
        'ServiceUsername', 'ServicePassword') `
{
    $session = Start-RemoteSession -ServerHost $AppServer
    $serviceCredential = New-Object System.Management.Automation.PSCredential($ServiceUsername,
        (ConvertTo-SecureString $ServicePassword -AsPlainText -Force))
    # TODO: Fix project name.
    $projectName = 'Example.Service'
    $binPath = "$src\$projectName\bin\$Configuration"
    $serviceName = $projectName
    $destinationPath = "$ApprootPath\$serviceName"

    Invoke-ServiceProjectDeployment -Session $session `
        -ServiceName $serviceName -ProjectName $projectName `
        -BinPath $binPath -DestinationPath $destinationPath `
        -ServiceCredential $serviceCredential

    Remove-PSSession $session
}
<% } // windowsServiceEnabled %>