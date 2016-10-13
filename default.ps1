Framework 4.6
$InformationPreference = 'Continue'
$env:PSModulePath += ";$PSScriptRoot\modules"

Properties `
{
    $nugetApiKey = $null
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

Task generate-docs -depends build `
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

# Before run, make sure that required modules are installed.
# Install-Module psake, Saritasa.General, Saritasa.Web -Scope CurrentUser -Force
Task publish-modules -depends build -requiredVariables @('nugetApiKey') `
{
    Get-ChildItem -Directory $modules | % `
        {
            Write-Information "Publishing $_ module..."
            try
            {
                Publish-Module -Path $_.FullName -NuGetApiKey $nugetApiKey 
            }
            catch [System.Exception]
            {
                $_.Exception
            }
        }
}

Task publish-scripts -requiredVariables @('nugetApiKey') `
{
    try
    {
        Write-Information "Publishing Install-WinrmHttps script..."
        Publish-Script -Path "$scripts\WinRM\Install-WinrmHttps.ps1" -NuGetApiKey $nugetApiKey 
    }
    catch [System.Exception]
    {
        $_.Exception
    }
}

Task build `
{
    Import-Module "$modules\Saritasa.General\Saritasa.General.psd1"
    Import-Module "$modules\Saritasa.Build\Saritasa.Build.psd1"
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
    Invoke-NugetRestore -SolutionPath "$src\Saritasa.PSGallery.sln"
    Invoke-SolutionBuild -SolutionPath "$src\Saritasa.PSGallery.sln" -Configuration 'Release'
    Copy-Item "$src\Saritasa.Git.GitFlowStatus\bin\Release\Saritasa.Git.GitFlowStatus.dll" $gitRoot
}
