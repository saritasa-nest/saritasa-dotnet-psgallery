$root = $PSScriptRoot

<#
.SYNOPSIS

.DESCRIPTION
Tasks with description starting with * are main. They are shown on the help screen. Other tasks are auxiliary.
#>
function Register-HelpTask
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "",
                                                       Scope="Function", Target="*")]

    [CmdletBinding()]
    param
    (
        [string] $Name = 'help',
        [bool] $Default = $true
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    Task $Name -description 'Display description of main tasks.' `
    {
        Write-Host 'Main Tasks' -ForegroundColor DarkMagenta -NoNewline
        Get-PSakeScriptTasks | Where-Object { $_.Description -Like '`**' } |
            Sort-Object -Property Name | 
            Format-Table -Property Name, @{ Label = 'Description'; Expression = { $_.Description -Replace '^\* ', '' } }
        
        Write-Host 'Execute ' -NoNewline -ForegroundColor DarkMagenta
        Write-Host 'psake -docs' -ForegroundColor Black -BackgroundColor DarkMagenta -NoNewline
        Write-Host ' to see all tasks.' -ForegroundColor DarkMagenta
    }
    
    if ($Default)
    {
        Task default -depends $Name -description 'Show automatically generated help.'
    }
}

function Register-UpdateGalleryTask
{
    [CmdletBinding()]
    param ()

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    Task 'update-gallery' -description '* Update all modules from Saritasa PS Gallery.' `
    {
        Get-ChildItem -Path $root -Include 'Saritasa*.ps*1' -Recurse | ForEach-Object `
            {
                Write-Information "Updating $($_.Name)..."
                Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Saritasa/PSGallery/master/modules/$($_.BaseName)/$($_.Name)" -OutFile "$root\$($_.Name)"
                Write-Information 'OK'
            }
    }
}
