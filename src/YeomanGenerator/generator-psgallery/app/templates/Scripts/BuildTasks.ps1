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

Task pre-build -depends update-version -description 'Restore NuGet packages, update version.' `
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
