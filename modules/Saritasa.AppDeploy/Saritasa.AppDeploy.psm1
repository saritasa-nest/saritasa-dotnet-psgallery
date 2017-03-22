Add-Type -TypeDefinition @"
   public enum AppDeployOverwriteMode
   {
      Backup = 0,
      Overwrite = 1
   }
"@

function Invoke-DesktopProjectDeployment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Runspaces.PSSession] $Session,
        [Parameter(Mandatory = $true)]
        [string] $BinPath,
        [Parameter(Mandatory = $true)]
        [string] $DestinationPath,
        [ScriptBlock] $BeforeDeploy,
        [ScriptBlock] $AfterDeploy,
        [AppDeployOverwriteMode] $OverwriteMode = [AppDeployOverwriteMode]::Backup
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    Write-Information 'Creating ZIP archive...'
    $archiveName = "$([guid]::NewGuid()).zip"
    Compress-Archive "$BinPath\*" $archiveName -Force
    Write-Information 'Done.'

    $remoteTempDir = Get-RemoteTempPath $Session
    $remoteArchive = "$remoteTempDir\$archiveName"

    Write-Information "Copying $archiveName to remote server..."
    Copy-Item ".\$archiveName" $remoteTempDir -ToSession $Session
    Write-Information 'Done.'

    if ($BeforeDeploy)
    {
        Invoke-Command -Session $Session -ScriptBlock $BeforeDeploy
    }

    if ($OverwriteMode -eq [AppDeployOverwriteMode]::Backup)
    {
        Invoke-Command -Session $Session -ScriptBlock `
            {
                $backupPath = "$($using:DestinationPath)Old"
                if (Test-Path $backupPath)
                {
                    Remove-Item $backupPath -Recurse
                }

                if (Test-Path $using:DestinationPath)
                {
                    $retries = 0
                    while ($true)
                    {
                        try
                        {
                            Rename-Item $using:DestinationPath $backupPath -EA Stop
                            break
                        }
                        catch
                        {
                            $retries++
                            if ($retries -eq 10)
                            {
                                throw
                            }
                            else
                            {
                                Write-Warning 'Warning: Rename operation failed. Retrying...'
                                Start-Sleep $retries
                            }
                        }
                    }
                }

                # Directory should exist, if PSCX is used.
                New-Item -ItemType directory $using:DestinationPath

                Expand-Archive $using:remoteArchive $using:DestinationPath
            }
    } # OverwriteMode - Backup
    elseif ($OverwriteMode -eq [AppDeployOverwriteMode]::Overwrite)
    {
        Invoke-Command -Session $session -ScriptBlock `
            {
                Expand-Archive $using:remoteArchive $using:DestinationPath -Force
            }
    }
    else
    {
        throw 'Unknown OverwriteMode.'
    }

    Invoke-Command -Session $Session -ScriptBlock `
        {
            $appName = (Get-Item $using:DestinationPath).BaseName
            Write-Information "$appName app is updated."
            Remove-Item $using:remoteTempDir -Recurse -ErrorAction Stop
        }

    if ($AfterDeploy)
    {
        Invoke-Command -Session $Session -ScriptBlock $AfterDeploy
    }
}

<#
.NOTES
User should have 'Log on as a service right (https://technet.microsoft.com/en-us/library/cc739424(v=ws.10).aspx).
Local user name example: .\administrator

Service user accounts: LocalService, NetworkService, LocalSystem
https://msdn.microsoft.com/en-us/library/windows/desktop/ms686005(v=vs.85).aspx

Credentials for built-in service user accounts:
New-Object System.Management.Automation.PSCredential('NT AUTHORITY\LocalService', (New-Object System.Security.SecureString))
New-Object System.Management.Automation.PSCredential('NT AUTHORITY\NetworkService', (New-Object System.Security.SecureString))
New-Object System.Management.Automation.PSCredential('.\LocalSystem', (New-Object System.Security.SecureString))
#>
function Invoke-ServiceProjectDeployment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Runspaces.PSSession] $Session,
        [Parameter(Mandatory = $true)]
        [string] $ServiceName,
        [Parameter(Mandatory = $true)]
        [string] $ProjectName,
        [Parameter(Mandatory = $true)]
        [string] $BinPath,
        [Parameter(Mandatory = $true)]
        [string] $DestinationPath,
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $ServiceCredential
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    Invoke-DesktopProjectDeployment -Session $Session -DestinationPath $DestinationPath -BinPath $BinPath  `
        -BeforeDeploy `
        {
            $service = Get-Service | Where-Object { $_.Name -eq $using:ServiceName }
            if ($service)
            {
                Stop-Service $service
                Write-Information "Service $using:ServiceName is stopped."
            }
            else
            {
                Write-Information "Service $using:ServiceName is not installed."
            }
        } `
        -AfterDeploy `
        {
            $service = Get-Service | Where-Object { $_.Name -eq $using:ServiceName }
            if ($service)
            {
                Start-Service $service -ErrorAction Stop
                Write-Information "Service $using:ServiceName is started."
            }
            else
            {
                Write-Information "Creating $using:ServiceName service..."

                $credential = $using:ServiceCredential
                if ($credential.UserName -notlike '*\*') # Not a domain user.
                {
                    $credential = New-Object System.Management.Automation.PSCredential(".\$($credential.UserName)", $credential.Password)
                }

                $service = New-Service -Name $using:ServiceName -ErrorAction Stop -Credential $credential `
                     -BinaryPathName "$using:DestinationPath\$using:ProjectName.exe"
                Write-Information "Done."

                Start-Service $using:ServiceName -ErrorAction Stop
                Write-Information "Service $using:ServiceName is started."
            }
        }
}
