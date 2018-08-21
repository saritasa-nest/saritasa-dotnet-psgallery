Properties `
{
    $Configuration = $null
    $MaxWarnings = 0
}

$root = $PSScriptRoot
$src = Resolve-Path "$root\<%= srcPath %>"
$workspace = Resolve-Path "$root\.."

Task pre-build -description 'Restore NuGet packages, copy configs.' `
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
