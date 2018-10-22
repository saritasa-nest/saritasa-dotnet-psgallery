Framework 4.6
$InformationPreference = 'Continue'
$env:PSModulePath += ";$PSScriptRoot\modules"

Properties `
{
    $NugetApiKey = $null
}

$root = $PSScriptRoot
$modules = "$PSScriptRoot\modules"
$scripts = "$PSScriptRoot\scripts"
$src = "$PSScriptRoot\src"

Task analyze -description 'Run PowerShell static analysis tool on all modules and scripts.' `
{
    $modules | Get-ChildItem -Include '*.ps1', '*.psd1', '*.psm1' -Recurse `
        -Exclude 'AddDelegationRules.ps1', 'SetupSiteForPublish.ps1' | Invoke-ScriptAnalyzer
}

Task build-docs -depends build `
{
    $descriptionRegex = [regex] "Description = '(.*)'"

    Write-Output '| Name                      | Description                                                                                                                      |'
    Write-Output '| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |'

    Get-ChildItem -Include '*.psd1' -Recurse | ForEach-Object `
        {
            Import-Module $_.BaseName
            GenerateMarkdown $_.BaseName

            $name = $_.BaseName
            (Get-Content $_) | Where-Object { $_ -Match $descriptionRegex } |
                Select-Object -First 1 | Out-Null
            $description = $matches[1]
            Write-Output "| [$name](docs/$name.md)`t`t`t| $description |"
        }

    Copy-Item .\scripts\Psake\Saritasa.PsakeExtensions.ps1 .\scripts\Psake\Saritasa.PsakeExtensions.psm1
    Import-Module .\scripts\Psake\Saritasa.PsakeExtensions.psm1
    GenerateMarkdown Saritasa.PsakeExtensions
    Remove-Item .\scripts\Psake\Saritasa.PsakeExtensions.psm1
}

function GenerateMarkdown([string] $moduleName)
{
    .\tools\psDoc\psDoc.ps1 -moduleName $moduleName -template .\tools\psDoc\out-markdown-template.ps1 -outputDir .\docs -fileName "$moduleName.md"
}

function IsModuleVersionAvailableInGallery
{
    [OutputType('System.Boolean')]
    param
    (
        $ModulePath
    )

    $psd1 = Get-ChildItem -Path $ModulePath -Filter "*.psd1"
    $fullPath = "$ModulePath\$psd1"

    $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($psd1)

    $rawModule = Get-Content $fullPath

    $regex = [regex]"(?m)ModuleVersion(\ )?=(\ )?\'(?<version>[0-9.]+)\'"

    $match = $regex.Match($rawModule)

    $moduleVersion = $null

    if ($match.Groups.Count -gt 0 -and $match.Groups["version"] -ne $null)
    {
        $captured = $match.Groups["version"];

        $moduleVersion = New-Object -TypeName "System.Version" -ArgumentList $captured.Value
    }

    if ($moduleVersion -eq $null)
    {
        throw "Can't parse version of module $ModulePath"
    }

    if ($moduleVersion.Build -eq -1)
    {
        $moduleVersion = New-Object -TypeName "System.Version" -ArgumentList @($moduleVersion.Major, $moduleVersion.Minor, 0)
    }

    $moduleVersionRaw = $moduleVersion.ToString(3)

    $module = Find-Module -Name $moduleName -RequiredVersion $moduleVersionRaw -ErrorAction SilentlyContinue

    $remoteModuleVersion = $null

    if ($module -ne $null)
    {
        $remoteModuleVersion = New-Object -TypeName "System.Version" -ArgumentList $module.Version
    }

    if ($remoteModuleVersion.Build -eq -1)
    {
        $remoteModuleVersion = New-Object -TypeName "System.Version" -ArgumentList @($remoteModuleVersion.Major, $remoteModuleVersion.Minor, 0)
    }

    return $remoteModuleVersion -ne $null -and $remoteModuleVersion -eq $moduleVersion -or $remoteModuleVersion -gt $moduleVersion
}

# Before run, make sure that required modules are installed.
# Install-Module psake, VSSetup -Scope CurrentUser -Force
Task publish-modules -depends build -requiredVariables @('NugetApiKey') `
{
    Remove-Item "$modules\Saritasa.Build\nuget.exe" -ErrorAction SilentlyContinue

    Get-ChildItem -Directory $modules | ForEach-Object `
        {
            Write-Information "Publishing $_ module..."
            try
            {
                if ((IsModuleVersionAvailableInGallery -ModulePath $_.FullName) -eq $false)
                {
                    Publish-Module -Path $_.FullName -NuGetApiKey $NugetApiKey
                }
                else
                {
                    Write-Information "Skipped"
                }
            }
            catch [System.Exception]
            {
                $_.Exception
            }
        }
}

Task build `
{
    # Tested on version 1.1.605.
    Exec { nuget.exe install StackExchange.Redis -OutputDirectory "$root\tmp" }

    $redisRoot = "$modules\Saritasa.Redis"
    Copy-Item "$root\tmp\StackExchange.Redis.*\lib\net46\StackExchange.Redis.dll" $redisRoot

    $gitRoot = "$modules\Saritasa.Git"
    Initialize-MSBuild
    Invoke-NugetRestore -SolutionPath "$src\Saritasa.PSGallery.sln"
    Invoke-SolutionBuild -SolutionPath "$src\Saritasa.PSGallery.sln" -Configuration 'Release'
    Copy-Item "$src\Saritasa.Git\bin\Release\Saritasa.Git.dll" $gitRoot

    $yeomanScriptsPath = "$src\YeomanGenerator\generator-psgallery\app\templates\Scripts"
    Copy-Item "$scripts\Psake\*.ps1" $yeomanScriptsPath
}

Task clean `
{
    Exec { git clean -xdf -e node_modules/ }
}
