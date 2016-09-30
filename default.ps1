$InformationPreference = 'Continue'

Properties `
{
    $nugetApiKey = $null
}

$root = $PSScriptRoot
$modules = "$PSScriptRoot\modules"
$scripts = "$PSScriptRoot\scripts"

Task analyze -description 'Run PowerShell static analysis tool on all modules and scripts.' `
{
    Get-ChildItem -Include '*.ps1', '*.psd1', '*.psm1' -Recurse `
        -Exclude 'AddDelegationRules.ps1', 'SetupSiteForPublish.ps1' | Invoke-ScriptAnalyzer
}

Task generate-docs -depends build `
{
    $descriptionRegex = [regex] "Description = '(.*)'"

    Write-Output '| Name                      | Description                                                                                                                      |'
    Write-Output '| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |'
    
    Import-Module .\modules\Saritasa.General\Saritasa.General.psd1
    Import-Module .\modules\Saritasa.Web\Saritasa.Web.psd1

    Get-ChildItem -Include '*.psd1' -Recurse | ForEach-Object `
        {
            GenerateMarkdown $_.FullName $_.BaseName

            $name = $_.BaseName
            (Get-Content $_) | Where-Object { $_ -Match $descriptionRegex } |
                Select-Object -First 1 | Out-Null
            $description = $matches[1]
            Write-Output "| [$name](docs/$name.md)`t`t`t| $description |"
        }
    
    Remove-Item .\modules\Saritasa.Prtg\Saritasa.Web.ps*1

    Copy-Item .\scripts\Psake\Saritasa.PsakeExtensions.ps1 .\scripts\Psake\Saritasa.PsakeExtensions.psm1
    GenerateMarkdown .\scripts\Psake\Saritasa.PsakeExtensions.psm1 Saritasa.PsakeExtensions
    Remove-Item .\scripts\Psake\Saritasa.PsakeExtensions.psm1
}

function GenerateMarkdown([string] $fileName, [string] $moduleName)
{
    if ($moduleName -eq 'Saritasa.Psake')
    {
        return
    }

    Import-Module $fileName
    .\tools\psDoc\psDoc.ps1 -moduleName $moduleName -template .\tools\psDoc\out-markdown-template.ps1 -outputDir .\docs -fileName "$moduleName.md"
}

# Before run, make sure that required modules are installed.
# Install-Module psake, Saritasa.General, Saritasa.Web -Scope CurrentUser -Force
Task publish- -depends build -requiredVariables @('nugetApiKey') `
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

    $redisLib = "$modules\Saritasa.Redis\Lib"
    if (!(Test-Path $redisLib))
    {
        New-Item $redisLib -ItemType Directory
    }

    Copy-Item "$root\tmp\StackExchange.Redis.*\lib\net46\StackExchange.Redis.dll" $redisLib
}
