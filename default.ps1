Task analyze -description 'Run PowerShell static analysis tool on all modules and scripts.' `
{
    Get-ChildItem -Include '*.ps1', '*.psd1', '*.psm1' -Recurse | Invoke-ScriptAnalyzer
}
