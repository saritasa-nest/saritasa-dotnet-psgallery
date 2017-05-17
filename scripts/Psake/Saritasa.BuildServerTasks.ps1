<#PSScriptInfo

.VERSION 1.0.1

.GUID 5bf3b9dd-b754-4e71-bb03-cb5c5a8101c7

.AUTHOR Anton Zimin

.COMPANYNAME Saritasa

.COPYRIGHT (c) 2017 Saritasa. All rights reserved.

.TAGS Jenkins Git

.LICENSEURI https://raw.githubusercontent.com/Saritasa/PSGallery/master/LICENSE

.PROJECTURI https://github.com/Saritasa/PSGallery

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES

.SYNOPSIS
Contains Psake tasks for build server configuration.

.DESCRIPTION

#>

Properties `
{
    $ServerHost = $null
    $AdminUsername = $null
    $AdminPassword = $null
    $WorkspacePath = $null
}

Task setup-jenkins -depends init-winrm -description 'Install Jenkins, change service account.' `
    -requiredVariables @('ServerHost') `
{
    $session = Start-RemoteSession -ServerHost $ServerHost

    Invoke-Command -Session $session -ScriptBlock `
        {
            $service = Get-Service 'Jenkins' -ErrorAction SilentlyContinue
            if ($service)
            {
                Write-Information 'Jenkins is installed already.'
            }
            else
            {
                Write-Information 'Installing Jenkins, Carbon...'
                cinst jenkins carbon -y
                if ($LASTEXITCODE)
                {
                    throw 'Chocolatey failed.'
                }

                # Set 'Log on as a service' security policy using Carbon.
                Grant-Privilege -Identity $using:AdminUsername -Privilege SeServiceLogonRight
                Write-Information 'User privileges are updated.'

                Write-Information 'Changing service account...'

                $username = $using:AdminUsername
                if ($username -notlike '*\*')
                {
                    $username = ".\$username"
                }

                $args = @('config', 'Jenkins', 'obj=', $username, 'password=', $using:AdminPassword)
                sc.exe $args
                if ($LASTEXITCODE)
                {
                    throw 'Service control failed.'
                }
                Restart-Service Jenkins
                Write-Information 'Done.'
            }
        }

    Remove-PSSession $session
}

Task setup-workspace -depends init-winrm -description 'Install Git, generate SSH keys, init workspace.' `
    -requiredVariables @('ServerHost', 'WorkspacePath') `
{
    $session = Start-RemoteSession -ServerHost $ServerHost
    Invoke-Command -Session $session -ScriptBlock `
        {
            cinst git -y
            if ($LASTEXITCODE)
            {
                throw 'Chocolatey failed.'
            }

            if (!(Test-Path "$env:HOMEDRIVE$env:HOMEPATH\.ssh\id_rsa"))
            {
                Write-Information 'SSH private key is not configured. Creating...'
                $passPhrase = '""'
                &'C:\Program Files\Git\usr\bin\ssh-keygen.exe' -b 2048 -t rsa -C "$env:COMPUTERNAME $(Get-Date -Format 'yyyy-MM-dd')" -q -N $passPhrase -f "/c/Users/$env:USERNAME/.ssh/id_rsa"
                Write-Information 'Done.'
            }

            $knownHostsFile = "$env:HOMEDRIVE$env:HOMEPATH\.ssh\known_hosts"
            if (!(Test-Path $knownHostsFile))
            {
                Write-Information 'Adding host signature to SSH known hosts...'
                $hostname = 'gitblit.saritasa.com'
                $tempFile = "$env:TEMP\" + [guid]::NewGuid()
                Resolve-DnsName $hostname | foreach `
                    {
                        Start-Process -Wait 'C:\Program Files\Git\usr\bin\ssh-keyscan.exe' -ArgumentList "$hostname,$($_.IP4Address)" `
                            -RedirectStandardOutput $tempFile -ErrorAction SilentlyContinue
                        Get-Content $tempFile | Add-Content "$env:HOMEDRIVE$env:HOMEPATH\.ssh\known_hosts"
                    }
                Remove-Item $tempFile
                Write-Information 'Done.'
            }

            $workspaceExists = Test-Path $using:WorkspacePath
            $gitExists = Test-Path "$using:WorkspacePath\.git"
            if (!($workspaceExists -and $gitExists))
            {
                Write-Information 'Creating workspace...'
                if (!$workspaceExists)
                {
                    New-Item -ItemType directory $using:WorkspacePath
                }

                # Make sure PATH variable is updated after Git install.
                $env:PATH = (@(,[Environment]::GetEnvironmentVariable('PATH', 'Machine') -Split ';') + @([Environment]::GetEnvironmentVariable('PATH', 'User') -Split ';') | Select -Unique) -Join ';'

                &'git.exe' init $using:WorkspacePath
                if ($LASTEXITCODE)
                {
                    throw 'Git failed.'
                }
                Write-Information 'Done.'
            }
        }

    Remove-PSSession $session
}

Task import-jenkins -depends init-winrm -description 'Copy Jenkins config and jobs to a remote server.' `
    -requiredVariables @('ServerHost') `
{
    $session = Start-RemoteSession -ServerHost $ServerHost

    Copy-Item -Path "$root\Jenkins\*" -Destination 'C:\Program Files (x86)\Jenkins' -ToSession $session -Recurse -Force

    Remove-PSSession $session
}

Task export-jenkins -depends init-winrm -description 'Download Jenkins config and jobs from a remote server.' `
    -requiredVariables @('ServerHost') `
{
    if (Test-Path "$root\Jenkins")
    {
        Remove-Item "$root\Jenkins" -Recurse -Force
    }

    $session = Start-RemoteSession -ServerHost $ServerHost
    $tempPath = Get-RemoteTempPath $session

    Invoke-Command -Session $session -ScriptBlock `
        {
            $jenkinsPath = 'C:\Program Files (x86)\Jenkins'
            Copy-Item "$jenkinsPath\*.xml" $using:tempPath

            $sourcePath = Join-Path $jenkinsPath 'jobs'
            $destPath = Join-Path $using:tempPath 'jobs'
            Get-ChildItem $sourcePath -Recurse -Include 'config.xml' | Foreach-Object `
                {
                    $destDir = Split-Path ($_.FullName -Replace [regex]::Escape($sourcePath), $destPath)
                    if (!(Test-Path $destDir))
                    {
                        New-Item -ItemType directory $destDir | Out-Null
                    }
                    Copy-Item $_ -Destination $destDir
                }
        }
    Copy-Item $tempPath -Destination "$root\Jenkins" -FromSession $session -Recurse -Force

    Invoke-Command -Session $session -ScriptBlock `
        {
            Remove-Item $using:tempPath -Recurse -Force
        }
    Remove-PSSession $session
}

Task write-ssh-key -description 'Display public SSH key for Git.' `
    -requiredVariables @('ServerHost') `
{
    $session = Start-RemoteSession -ServerHost $ServerHost

    Invoke-Command -Session $session -ScriptBlock `
        {
            Write-Information "`n`n`nSSH public key:"
            Write-Information (Get-Content "$env:HOMEDRIVE$env:HOMEPATH\.ssh\id_rsa.pub")
        }

    Remove-PSSession $session
}

Task write-jenkins-password -description 'Display Jenkins default password for initial configuration.' `
    -requiredVariables @('ServerHost') `
{
    $session = Start-RemoteSession -ServerHost $ServerHost

    Invoke-Command -Session $session -ScriptBlock `
        {
            $jenkinsPasswordFile = 'C:\Program Files (x86)\Jenkins\secrets\initialAdminPassword'
            if (Test-Path $jenkinsPasswordFile)
            {
                Write-Information "`nJenkins admin password:"
                Write-Information (Get-Content $jenkinsPasswordFile)
            }
            else
            {
                Write-Information "`nJenkins is configured already."
            }
        }

    Remove-PSSession $session
}
