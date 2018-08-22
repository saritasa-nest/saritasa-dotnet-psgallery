Properties `
{
    $Configuration = $null
    $MaxWarnings = 0
    $InformationalVersion = $null
    $MajorMinorPatch = $null
}

$root = $PSScriptRoot
$src = Resolve-Path "$root\<%= srcPath %>"
$workspace = Resolve-Path "$root\.."

Task pre-build -depends copy-configs, update-version -description 'Copy configs, update version, restore NuGet packages.' `
{
    $configFilename = "$workspace\Config.$Environment.ps1"
    $templateFilename = "$workspace\Config.$Environment.ps1.template"

    if (!(Test-Path $configFilename) -and (Test-Path $templateFilename))
    {
        Write-Warning "Did you forget to copy $templateFilename to $($configFilename)?"
    }

    Initialize-MSBuild
<% if (!netCoreUsed) { %>
    # Invoke-NugetRestore -SolutionPath "$src\Example.sln"
<% } %>
}

Task build -depends pre-build -description '* Build all projects.' `
    -requiredVariables @('Configuration') `
{
<% if (netCoreUsed) { %>
    # Exec { dotnet build -c $Configuration "$src\Example.sln" }
<% } else { %>
    # Invoke-SolutionBuild -SolutionPath "$src\Example.sln" -Configuration $Configuration
<% } %>
}

Task clean -description '* Clean up workspace.' `
{
    Exec { git clean -xdf -e packages/ -e node_modules/ }
}

Task copy-configs -description 'Create configs based on App.config.template and Web.config.template if they don''t exist.' `
{
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
    if (!(Test-Path $configFile))
    {
        Copy-Item $templateFile $configFile
    }

    Update-VariablesInFile -Path $configFile `
        -Variables `
            @{
                DatabaseServer = $DatabaseServer
                DatabaseUsername = $DatabaseUsername
                DatabasePassword = $DatabasePassword
            }
<% } %>
}

Task update-version -description 'Replace package version in web project.' `
    -requiredVariables @('MajorMinorPatch', 'InformationalVersion') `
{
    if ($Environment -eq 'Development') # It's a developer machine.
    {
        return
    }

    $branchName = Exec { git rev-parse --abbrev-ref HEAD }

    if ($branchName -like 'origin/*')
    {
        throw "Expected local branch. Got: $branchName"
    }

    if ($branchName -eq 'master')
    {
        $tag = Exec { git describe --exact-match --tags }
        if (!$tag)
        {
            throw "Production releases without tag are not allowed."
        }
    }

<% if (netCoreUsed) { %>
    # $fileName = "$src\Example\Example.csproj"
    # Get-Content $fileName |
    #     ForEach-Object { $_ -replace '<Version>[\d\.\w+-]*</Version>', "<Version>$InformationalVersion</Version>" `
    #                         -replace '<AssemblyVersion>[\d\.]*</AssemblyVersion>', "<AssemblyVersion>$MajorMinorPatch.0</AssemblyVersion>" } |
    #     Set-Content $fileName -Encoding UTF8
<% } else { %>
    Exec { GitVersion.exe /updateassemblyinfo }
<% } %>
}

Task code-analysis -depends pre-build `
    -requiredVariables @('Configuration', 'MaxWarnings') `
{
    $buildParams = @("/p:Environment=$Environment")
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
    $projectName = 'Example.Tests'
<% if (netCoreUsed) { %>
    Exec { dotnet test "$src\$projectName\$projectName.csproj" }
<% } else { %>
    Invoke-ProjectBuild "$src\$projectName\$projectName.csproj" -Configuration $Configuration
    Invoke-XunitRunner "$src\$projectName\bin\$Configuration\$projectName.dll"
<% } %>
}
<% } %>