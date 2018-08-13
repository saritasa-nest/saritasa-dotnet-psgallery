Properties `
{
    $Configuration = $null
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

    # Invoke-NugetRestore -SolutionPath "$src\Example.sln"
}

Task build -depends pre-build -description '* Build all projects.' `
    -requiredVariables @('Configuration') `
{
    # Invoke-SolutionBuild -SolutionPath "$src\Example.sln" -Configuration $Configuration
}
