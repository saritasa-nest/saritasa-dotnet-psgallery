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

function ParsePsd1
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [Microsoft.PowerShell.DesiredStateConfiguration.ArgumentToConfigurationDataTransformation()]
        [hashtable] $Data
    )
    return $Data
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
    $moduleData = ParsePsd1 -Data $fullPath
    $moduleVersion = $moduleData.ModuleVersion

    $module = Find-Module -Name $moduleData.RootModule -RequiredVersion $moduleVersion -ErrorAction SilentlyContinue
    return $module -ne $null -and $module.Version -eq $moduleVersion -or $module.Version -gt $moduleVersion
}

# Before run, make sure that required modules are installed.
# Install-Module psake, VSSetup -Scope CurrentUser -Force
Task publish-modules -depends build -requiredVariables @('NugetApiKey') `
{
    Remove-Item "$modules\Saritasa.Build\nuget.exe" -ErrorAction SilentlyContinue

    Get-ChildItem -Directory $modules | % `
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

Task publish-scripts -requiredVariables @('NugetApiKey') `
{
    try
    {
        Write-Information "Publishing Install-WinrmHttps script..."
        Publish-Script -Path "$scripts\WinRM\Install-WinrmHttps.ps1" -NuGetApiKey $NugetApiKey
    }
    catch [System.Exception]
    {
        $_.Exception
    }
}

Task build `
{
    Install-NugetCli -Destination "$root\tools"
    $nugetExePath = "$root\tools\nuget.exe"

    # Tested on version 1.1.605.
    &$nugetExePath install StackExchange.Redis -OutputDirectory "$root\tmp"
    if ($LASTEXITCODE)
    {
        throw 'NuGet failed.'
    }

    $redisRoot = "$modules\Saritasa.Redis"
    Copy-Item "$root\tmp\StackExchange.Redis.*\lib\net46\StackExchange.Redis.dll" $redisRoot

    $gitRoot = "$modules\Saritasa.Git"
    Initialize-MSBuild
    Invoke-NugetRestore -SolutionPath "$src\Saritasa.PSGallery.sln"
    Invoke-SolutionBuild -SolutionPath "$src\Saritasa.PSGallery.sln" -Configuration 'Release'
    Copy-Item "$src\Saritasa.Git.GitFlowStatus\bin\Release\Saritasa.Git.GitFlowStatus.dll" $gitRoot

    $yeomanScriptsPath = "$src\YeomanGenerator\generator-psgallery\app\templates\Scripts"
    Copy-Item "$scripts\Psake\Saritasa.AdminTasks.ps1" $yeomanScriptsPath
    Copy-Item "$scripts\Psake\Saritasa.GitTasks.ps1" $yeomanScriptsPath
    Copy-Item "$scripts\Psake\Saritasa.PsakeExtensions.ps1" $yeomanScriptsPath
    Copy-Item "$scripts\Psake\Saritasa.PsakeTasks.ps1" $yeomanScriptsPath
}
