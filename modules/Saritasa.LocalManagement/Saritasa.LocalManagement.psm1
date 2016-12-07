<#
.SYNOPSIS
Returns $true if user has Administrator role.
#>
function Test-UserIsAdministrator
{
    ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
}
