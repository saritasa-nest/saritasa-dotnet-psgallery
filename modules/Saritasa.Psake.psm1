# Tasks with description starting with * are main. They are shown on the help screen.
# Other tasks are auxiliary.
function Register-HelpTask([string] $name = 'help', [bool] $default = $true)
{
    Task $name -description 'Display description of main tasks.' `
    {
        Write-Host 'Main Tasks' -ForegroundColor DarkMagenta -NoNewline
        Get-PSakeScriptTasks | ? { $_.Description -Like '`**' } | Format-Table -Property Name, @{ Label = 'Description'; Expression = { $_.Description -Replace '^\* ', '' } }
        
        Write-Host 'Execute ' -NoNewline -ForegroundColor DarkMagenta
        Write-Host 'psake -docs' -ForegroundColor Black -BackgroundColor DarkMagenta -NoNewline
        Write-Host ' to see all tasks.' -ForegroundColor DarkMagenta
    }
    
    if ($default)
    {
        Task default -depends $name -description 'Show automatically generated help.'
    }
}
