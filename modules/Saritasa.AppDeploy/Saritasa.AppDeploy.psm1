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
        [string] $ApprootPath,
        [Parameter(Mandatory = $true)]
        [string] $InstanceName,
        [Parameter(Mandatory = $true)]
        [string] $BinPath,
        [ScriptBlock] $BeforeDeploy,
        [ScriptBlock] $AfterDeploy,
        [AppDeployOverwriteMode] $OverwriteMode = [AppDeployOverwriteMode]::Backup
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    Write-Information 'Creating ZIP archive...'
    $archiveName = "${InstanceName}.zip"
    Compress-Archive "$BinPath\*" $archiveName -Force
    Write-Information 'Done.'
    
    $remoteTempDir = Get-RemoteTempPath $Session
    $remoteArchive = "$remoteTempDir\$archiveName"
    $destinationPath = "$ApprootPath\$InstanceName"
    
    Write-Information "Copying $archiveName to remote server..."
    Copy-Item ".\$archiveName" $remoteTempDir -ToSession $Session
    Write-Information 'Done.'
    
    Invoke-Command -Session $Session -ScriptBlock $BeforeDeploy

    if ($OverwriteMode -eq [AppDeployOverwriteMode]::Backup)
    {
        Invoke-Command -Session $Session -ScriptBlock `
            {       
                $backupPath = "$($using:destinationPath)Old"
                if (Test-Path $backupPath)
                {
                    Remove-Item $backupPath -Recurse
                }
                
                if (Test-Path $using:destinationPath)
                {
                    $retries = 0
                    while ($true)
                    {
                        try
                        {
                            Rename-Item $using:destinationPath $backupPath -EA Stop
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
                New-Item -ItemType directory $using:destinationPath
            
                Expand-Archive $using:remoteArchive $using:destinationPath
            }
    } # OverwriteMode - Backup
    elseif ($OverwriteMode -eq [AppDeployOverwriteMode]::Overwrite)
    {
        Invoke-Command -Session $session -ScriptBlock `
            {
                Expand-Archive $using:remoteArchive $using:destinationPath -Force
            }
    }
    else
    {
        throw 'Unknown OverwriteMode.'
    }

    Invoke-Command -Session $Session -ScriptBlock `
        {
            Write-Information "$using:InstanceName app is updated."
            Remove-Item $using:remoteTempDir -Recurse -ErrorAction Stop
        }

    Invoke-Command -Session $Session -ScriptBlock $AfterDeploy
}

<#
.NOTES
User should have 'Log on as a service right (https://technet.microsoft.com/en-us/library/cc739424(v=ws.10).aspx).
Local user name example: .\administrator
#>
function Invoke-ServiceProjectDeployment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Runspaces.PSSession] $Session,
        [Parameter(Mandatory = $true)]
        [string] $ApprootPath,
        [Parameter(Mandatory = $true)]
        [string] $ServiceName,
        [Parameter(Mandatory = $true)]
        [string] $ProjectName,
        [Parameter(Mandatory = $true)]
        [string] $BinPath,
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $ServiceCredential
    )

    Invoke-DesktopProjectDeployment -Session $Session -ApprootPath $ApprootPath -InstanceName $ServiceName -BinPath $BinPath  `
        -BeforeDeploy `
        {
            $service = Get-Service | ? { $_.Name -eq $using:ServiceName }
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
            $service = Get-Service | ? { $_.Name -eq $using:ServiceName }
            if ($service)
            {
                Start-Service $service -ErrorAction Stop
                Write-Information "Service $using:ServiceName is started."
            }
            else
            {
                Write-Information "Creating $using:ServiceName service..."
                
                $service = New-Service -Name $using:ServiceName -ErrorAction Stop -Credential $using:ServiceCredential `
                     -BinaryPathName "$using:ApprootPath\$using:ServiceName\$using:ProjectName.exe"
                Write-Information "Done."
                
                Start-Service $using:ServiceName -ErrorAction Stop
                Write-Information "Service $using:ServiceName is started."
            }
        }
}
