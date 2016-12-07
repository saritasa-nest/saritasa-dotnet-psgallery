Properties `
{
    $Configuration = $null
}

$root = $PSScriptRoot
$src = Resolve-Path "$root\..\src"

Task pre-build -description 'Restore NuGet packages, copy configs.' `
{
    # Invoke-NugetRestore "$src\Example.sln"
    # Copy-DotnetConfig "$src\Example\Web.config.template"
}

Task build -depends pre-build -description '* Build all projects.' `
    -requiredVariables @('Configuration') `
{
    # Invoke-SolutionBuild -SolutionPath "$src\Example.sln" -Configuration $Configuration
}
