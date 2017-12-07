Enum AppDeployOverwriteMode
{
    Backup = 0
    Overwrite = 1
}

<#
.SYNOPSIS
Deploys the folder contents to a remote computer.

.PARAMETER OverwriteMode
The logic which should be used during copy
If set to Backup, the destination folder first will be backed up and then the files will be transferred
If set to Overwrite, the destination folder contents will be overwritten with the BinPath fiels

.EXAMPLE
PS C:\> $s = New-PSSession
PS C:\> Invoke-DesktopProjectDeployment $s -BinPath .\Project\MyProject\bin\Release -DestinationPath C:\inetpub\www\myproject -OverwriteMode [AppDeployOverwriteMode]::Overwrite

In this example, the contents of MyProject\bin\Release folder will be placed on a remote server under myproject folder.
If this folder already exists, the files in it will be replaced with newest version.
Files which do exist in destination folder, but not exist in source folder, will not be deleted.
#>
function Invoke-DesktopProjectDeployment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Runspaces.PSSession] $Session,
        # Folder path which contents will be copied over
        [Parameter(Mandatory = $true)]
        [string] $BinPath,
        # Folder path where the files should be placed
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
.SYNOPSIS
Deploys a service to a remote computer.

.DESCRIPTION
Deploys a service to a remote computer by copying over the provided files and restarting the service.
If service does not exist, it will be automatically created.

.EXAMPLE
PS C:\> $s = New-PSSession
PS C:\> Invoke-ServiceProjectDeployment $s -ServiceName MyWebSite -ProjectName Web -BinPath .\Project\MyWebSite\bin\Release -DestinationPath C:\inetpub\www\MyWebSite

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
        # Name of deploying service on a remote computer
        [Parameter(Mandatory = $true)]
        [string] $ServiceName,
        # The name of executable which should be used to run the service
        [Parameter(Mandatory = $true)]
        [string] $ProjectName,
        # Folder path containing files which should be deployed
        [Parameter(Mandatory = $true)]
        [string] $BinPath,
        # Destination path on remote computer
        [Parameter(Mandatory = $true)]
        [string] $DestinationPath,
        # Credentials to be used to create a new service if it does not exist on remote computer
        [System.Management.Automation.Credential()]
        [System.Management.Automation.PSCredential] $ServiceCredential
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    Invoke-DesktopProjectDeployment -Session $Session -DestinationPath $DestinationPath -BinPath $BinPath  `
        -BeforeDeploy `
        {
            $service = Get-Service -Name $using:ServiceName -ErrorAction SilentlyContinue
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
            $service = Get-Service -Name $using:ServiceName -ErrorAction SilentlyContinue
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
