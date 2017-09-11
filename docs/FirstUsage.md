# First Usage

The document describes how to setup first simple project. We will setup build and deploy process, show basic project structure. Make sure you have installed [psake](https://github.com/psake/psake) and [PSGallery](GettingStarted.md) into your project.

## Create First Task

You may find `default.ps` file and `scripts` directories in the root of your project. `default.ps1` is used for Psake task runner and it is an entry point. It contains project properties and includes all main configuration. `scripts` directory contains PSGallery modules and predefined Psake tasks. Example:

```
./
scripts/          // Psake modules and build files.
src/              // Application.
default.ps1       // Entry point for Psake.
```

Let's overview Psake entry point with comments:

```powershell
# What .NET framework should Psake use.
Framework 4.6
$InformationPreference = 'Continue'
$env:PSModulePath += ";$PSScriptRoot\scripts\modules"

# Include modules, we have them locally.
. .\scripts\Saritasa.GitTasks.ps1
. .\scripts\Saritasa.PsakeExtensions.ps1
. .\scripts\Saritasa.PsakeTasks.ps1

# Our custom tasks. When we have a lot of tasks it is better to separate them by files.
. .\scripts\BuildTasks.ps1
. .\scripts\PublishTasks.ps1

# Global properties.
Properties `
{
    $Configuration = 'Debug'
    $Environment = 'Development'
}
```

We can start by creating simple task in `scripts\BuildTasks.ps1` file. Add following content to the end of file:

```powershell
Task test `
    -description 'Test task.' `
    -requiredVariables @('Param') `
{
    Write-Information "You are using configuration $Configuration with param value $Param."
}
```

It is recommended to have all parameters required for tasks in properties section. So now to use `Param` variable you should update properties section:

```powershell
Properties `
{
    $Param = $null
}
```

Without this `Param` variable will not be defined even if you provide it within command line. Now you can call it:

```shell
psake test -properties @{Param=123}
```

The output should be:

```
You are using configuration Debug with param value 123.
```

We have set up simple task with one required parameter `param`. In tasks global properties are available for you as parameters. For example `$Configuration` is reserved for solution build configuration and `$Environment` is for current used environment. By setting different values to script we can change task behavior. In current example we need to provide value for `Param` and have to pass `-properties` with Psake call that would override default value:

```shell
psake test -properties @{Configuration='Release';Param=123}
```

Now it is done! You can type `psake -docs` and see that our test task is enumerated. We can go ahead a do something useful.

## Build and Publish Project

The idea of PSGallery project is to provide set of useful Powershell functions to make CI process easier. Let's build and publish our project to remote Windows server! To build use `Invoke-SolutionBuild` function.

**Note** The server should be configured and IIS needs to be installed. You should have remote management service running (see [WinRM Configuration](WinRMConfiguration.md) section) and IIS with WebDeploy installed. You can do this by run `Install-Iis $ServerHost -ManagementService -WebDeploy` on your local host.

```powershell
Task build `
    -depends pre-build `
    -description '* Build project.' `
    -requiredVariables @('Configuration') `
{
    Initialize-MSBuild
    Invoke-NugetRestore -SolutionPath "$src\WebApplication1.sln"
    Invoke-SolutionBuild -SolutionPath "$src\WebApplication1.sln" -Configuration $Configuration
}
```

You can run `psake build` to build project now. Some things to note:

1. `-depends` keyword means that there are depended tasks need to be performed before.
2. `$src` is already presented as global variable and means root directory for our source code.
3. Even if configuration variable is required there is a property `Configuration` and it will be used instead if no property passed.

After build we try to deploy project to IIS server, for that use `Invoke-WebDeployment` function:

```powershell
Task pre-build `
{
    Initialize-MSBuild
    Invoke-NugetRestore -SolutionPath "$src\WebApplication1.sln"
}

Task deploy `
    -depends pre-build `
    -description '* Deploy project.' `
    -requiredVariables @('Configuration','DeployUsername','DeployPassword','ServerHost','SiteName') `
{
    Invoke-PackageBuild "$src\WebApplication1\WebApplication1.csproj" "$src\WebApplication1.zip" $Configuration -Precompile $true
    $credential = New-Object System.Management.Automation.PSCredential($DeployUsername, (ConvertTo-SecureString $DeployPassword -AsPlainText -Force))
    Initialize-WebDeploy -Credential $credential
    Invoke-WebDeployment "$src\WebApplication1.zip" $ServerHost $SiteName -Application ''
}
```

Do not forget to update properties section:

```powershell
Properties `
{
    $ServerHost = $null
    $SiteName = $null
    $DeployUsername = $null
    $DeployPassword = $null
}
```

When you try to run it you will get `The term 'Invoke-PackageBuild' is not recognized as the name of a cmdlet, function, script file...` error. That's because we do not have a module installed for the specified function. You can follow [guide](GettingStarted.md) to add new module run:

```powershell
Save-Module Saritasa.WebDeploy -Path .\scripts\modules\
```

After that you can invoke (example):

```shell
psake deploy -properties @{DeployUsername='Administrator';DeployPassword='PASSWORD';ServerHost='winsrvbox';SiteName='WebApp';Configuration='Release'}
```

If server configured correctly the website now should be deployed to `winsrvbox` host.
