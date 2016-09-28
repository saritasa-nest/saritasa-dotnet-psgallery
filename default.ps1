Task analyze -description 'Run PowerShell static analysis tool on all modules and scripts.' `
{
    Get-ChildItem -Include '*.ps1', '*.psd1', '*.psm1' -Recurse `
        -Exclude 'AddDelegationRules.ps1', 'SetupSiteForPublish.ps1' | Invoke-ScriptAnalyzer
}

Task generate-docs `
{
    $descriptionRegex = [regex] "Description = '(.*)'"

    Write-Output '| Name                      | Description                                                                                                                      |'
    Write-Output '| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |'
    
    Copy-Item .\modules\Saritasa.Web\Saritasa.Web.ps*1 C:\Work\PSGallery\modules\Saritasa.Prtg

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
    Import-Module $fileName
    .\tools\psDoc\psDoc.ps1 -moduleName $moduleName -template .\tools\psDoc\out-markdown-template.ps1 -outputDir .\docs -fileName "$moduleName.md"
    Remove-Module $moduleName
}
