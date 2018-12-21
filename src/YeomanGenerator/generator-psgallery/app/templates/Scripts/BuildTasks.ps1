Properties `
{
    $Configuration = $null
    $MaxWarnings = 0
    $AssemblySemVer = $null
    $InformationalVersion = $null
}

$root = $PSScriptRoot
$src = Resolve-Path "$root\<%= srcPath %>"
$workspace = Resolve-Path "$root\.."

Task pre-build -depends copy-configs, update-version -description 'Copy configs, update version, restore NuGet packages.' `
{
    if (!$IsLinux)
    {
        Initialize-MSBuild
    }
<% if (!netCoreUsed) { %>
    # TODO: Fix solution name.
    Invoke-NugetRestore -SolutionPath "$src\Example.sln"
<% } %>
}

Task build -depends pre-build -description '* Build all projects.' `
    -requiredVariables @('Configuration') `
{
    # TODO: Fix solution name.
<% if (netCoreUsed) { %>
    Exec { dotnet build -c $Configuration "$src\Example.sln" }
<% } else { %>
    $buildParams = @("/p:Environment=$Environment")
    Invoke-ProjectBuild -ProjectPath "$src\Example.sln" -Configuration $Configuration `
        -BuildParams $buildParams
<% } %>
}

Task clean -description '* Clean up workspace.' `
{
    Exec { git clean -xdf -e packages/ -e node_modules/ }
}

Task copy-configs -description 'Create configs based on App.config.template and Web.config.template if they don''t exist.' `
{
    $configFilename = "$workspace\Config.$Environment.ps1"
    $templateFilename = "$workspace\Config.$Environment.ps1.template"

    if ($IsLocalDevelopment -and !(Test-Path $configFilename) -and (Test-Path $templateFilename))
    {
        Write-Warning "Did you forget to copy $templateFilename to $($configFilename)?"
        return
    }

    # TODO: Fix project name.
<% if (netCoreUsed) { %>
    $projectName = 'Example.Web'
    $templateFile = "$src\$projectName\appsettings.$Environment.json.template"
    $configFile = "$src\$projectName\appsettings.$Environment.json"
<% } else if (webEnabled) { %>
    $projectName = 'Example.Web'
    $templateFile = "$src\$projectName\Web.$Environment.config.template"
    $configFile = "$src\$projectName\Web.$Environment.config"
<% } else if (windowsServiceEnabled) { %>
    $projectName = 'Example.App'
    $templateFile = "$src\$projectName\App.$Environment.config.template"
    $configFile = "$src\$projectName\App.$Environment.config"
<% } %>
<% if (webEnabled || windowsServiceEnabled) { %>
    Copy-DotnetConfig $templateFile
<% if (netCoreUsed) { %>
    Update-VariablesInFile -Path $configFile `
        -Variables `
            @{
                DatabaseServer = ($DatabaseServer -replace '\\', '\\')
                DatabaseUsername = ($DatabaseUsername -replace '\\', '\\')
                DatabasePassword = ($DatabasePassword -replace '\\', '\\')
            }
<% } else { %>
    Update-VariablesInFile -Path $configFile `
        -Variables `
            @{
                DatabaseServer = $DatabaseServer
                DatabaseUsername = $DatabaseUsername
                DatabasePassword = $DatabasePassword
            }
<% } // netCoreUsed %>
<% } // webEnabled || windowsServiceEnabled %>
}

Task update-version -description 'Replace package version in web project.' `
    -depends get-version `
    -requiredVariables @('AssemblySemVer', 'InformationalVersion') `
{
    if ($IsLocalDevelopment) # It's a developer machine.
    {
        return
    }

<% if (netCoreUsed) { %>
    # TODO: Fix project name.
    $fileName = "$src\Example\Example.csproj"
    $lines = Get-Content $fileName
    $lines | ForEach-Object { $_ -replace '<Version>[\d\.\w+-]*</Version>', "<Version>$InformationalVersion</Version>" `
        -replace '<AssemblyVersion>[\d\.]*</AssemblyVersion>', "<AssemblyVersion>$AssemblySemVer</AssemblyVersion>" } |
        Set-Content $fileName -Encoding UTF8
<% } else { %>
    Update-AssemblyInfoFile -Path $src -AssemblyVersion `
        $AssemblySemVer -AssemblyFileVersion $AssemblySemVer -AssemblyInfoVersion $InformationalVersion
<% } %>
}

Task code-analysis -depends pre-build `
    -requiredVariables @('Configuration', 'MaxWarnings') `
{
    $buildParams = @("/p:Environment=$Environment")
    # TODO: Fix solution name.
    $solutionPath = "$src\Example.sln"
    $logFile = "$workspace\Warnings.txt"

    Exec { msbuild.exe $solutionPath '/m' '/t:Build' "/p:Configuration=$Configuration" '/verbosity:normal' '/fileLogger' "/fileloggerparameters:WarningsOnly;LogFile=$logFile" $buildParams }

    $warnings = (Get-Content $logFile | Measure-Object -Line).Lines
    Write-Information "Warnings: $warnings"

    if ($warnings -gt $MaxWarnings)
    {
        throw "Warnings number ($warnings) is upper than limit ($MaxWarnings)."
    }
}

<% if (testsUsed) { %>
Task run-tests -depends pre-build `
    -description '* Run xUnit tests.' `
    -requiredVariables @('Configuration') `
{
    # TODO: Fix project name.
    $projectName = 'Example.Tests'
<% if (netCoreUsed) { %>
    Exec { dotnet test "$src\$projectName\$projectName.csproj" }
<% } else { %>
    Invoke-ProjectBuild "$src\$projectName\$projectName.csproj" -Configuration $Configuration
    Invoke-XunitRunner "$src\$projectName\bin\$Configuration\$projectName.dll"
<% } %>
}
<% } %>