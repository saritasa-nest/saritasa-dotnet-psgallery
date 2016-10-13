$credential = $null
$winrmPort = 5986
$authentication = [System.Management.Automation.Runspaces.AuthenticationMechanism]::Default

function Initialize-RemoteManagement
{
    [CmdletBinding()]
    param
    (
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,
        [int] $Port,
        [System.Management.Automation.Runspaces.AuthenticationMechanism]
        $Authentication
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if ($Credential)
    {
        $script:credential = $Credential
    }

    if ($Port)
    {
        $script:winrmPort = $Port
    }

    if ($Authentication)
    {
        $script:authentication = $Authentication
    }
}

function Start-RemoteSession
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $ServerHost
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    
    New-PSSession -UseSSL -Credential $credential -ComputerName ([System.Net.Dns]::GetHostByName($ServerHost).Hostname) `
        -Authentication $authentication -Port $winrmPort
}

function CheckSession
{
    param
    (
        [string] $ServerHost,
        [System.Management.Automation.Runspaces.PSSession] $Session
    )
    
    if (!$Session)
    {
        if (!$ServerHost)
        {
            throw 'ServerHost is not set.'
        }
        $Session = Start-RemoteSession $ServerHost
    }
    
    $Session
}

<#
.SYNOPSIS
Executes a script on a remote server.

.NOTES
Based on code by mjolinor.
http://stackoverflow.com/a/27799658/991267
#>
function Invoke-RemoteScript
{
    [CmdletBinding()]
    param
    (
        [string] $Path,
        [hashtable] $Parameters,
        [string] $ServerHost,
        [System.Management.Automation.Runspaces.PSSession] $Session
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    
    $Session = CheckSession $ServerHost $Session
    
    $scriptContent = Get-Content $Path -Raw
    $scriptParams = &{$args} @Parameters
    $sb = [scriptblock]::create("&{ $scriptContent } $scriptParams")

    Invoke-Command -Session $Session -ScriptBlock $sb
}
