<#
.SYNOPSIS
Returns $true if user has Administrator role.
#>
function Test-UserIsAdministrator
{
    [CmdletBinding()]
    param ()

    ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
}

<#
.SYNOPSIS
Sets 'password never expires' flag for local user.
.NOTES
Requires administrator permissions.
#>
function Set-PasswordNeverExpires
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "",
                                                       Scope="Function", Target="*")]

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $Username
    )

    $ADS_UF_DONT_EXPIRE_PASSWD = 0x10000

    $user = [adsi] "WinNT://./$Username"
    $user.UserFlags = $user.UserFlags[0] -bor $ADS_UF_DONT_EXPIRE_PASSWD
    $user.SetInfo()
}
