function ExecuteAppCmd
{
    param
    (
        [string] $ServerHost,
        [string] $ConfigFilename,
        [string[]] $Arguments
    )

    $config = Get-Content $ConfigFilename
    $appCmd = "$env:SystemRoot\System32\inetsrv\appcmd"

    # Site elements contain paths to applications.
    $appPaths = ([xml]$config).SelectNodes('/appcmd/SITE/site/application/virtualDirectory').physicalPath
    $createDirectoriesSB = `
        {
            if ($appPaths)
            {
                Write-Information 'Creating directories...'
                foreach ($path in $appPaths)
                {
                    New-Item -ItemType Directory $path -ErrorAction SilentlyContinue | Out-Null
                    Write-Information "`t$path"
                }
                Write-Information 'Done.'
            }
        }

    if (!(Test-IsLocalhost $ServerHost)) # Remote server.
    {
        $session = Start-RemoteSession $ServerHost

        Invoke-Command -Session $session -ScriptBlock { $appPaths = $using:appPaths }
        Invoke-Command -Session $session -ScriptBlock $createDirectoriesSB

        Invoke-Command -Session $session -ScriptBlock { $using:config | &$using:appCmd $using:Arguments }

        Remove-PSSession $session
    }
    else # Local server.
    {
        &$createDirectoriesSB

        Invoke-Command { $config | &$appCmd $Arguments }
    }

    if ($LASTEXITCODE)
    {
        throw 'AppCmd failed.'
    }
}

function GetAppCmdOutput
{
    param
    (
        [string] $ServerHost,
        [string[]] $Arguments
    )

    $appCmd = "$env:SystemRoot\System32\inetsrv\appcmd"

    if ($ServerHost) # Remote server.
    {
        $session = Start-RemoteSession $ServerHost

        $output = Invoke-Command -Session $session -ScriptBlock { &$using:appCmd $using:Arguments }

        Remove-PSSession $session
    }
    else # Local server.
    {
        $output = Invoke-Command { &$appCmd $Arguments }
    }

    if ($LASTEXITCODE)
    {
        throw 'AppCmd failed.'
    }

    $output | Where-Object { $_.Length -ne 0 }
}

function Import-AppPool
{
    [CmdletBinding()]
    param
    (
        [string] $ServerHost,
        [Parameter(Mandatory = $true)]
        [string] $ConfigFilename
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    ExecuteAppCmd $ServerHost $ConfigFilename @('add', 'apppool', '/in') $false
    Write-Information 'App pools are updated.'
}

function Import-Site
{
    [CmdletBinding()]
    param
    (
        [string] $ServerHost,
        [Parameter(Mandatory = $true)]
        [string] $ConfigFilename
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    ExecuteAppCmd $ServerHost $ConfigFilename @('add', 'site', '/in') $false
    Write-Information 'Web sites are updated.'
}

function CreateOutputDirectory([string] $Filename)
{
    $dir = Split-Path $Filename
    if (!(Test-Path $dir))
    {
        New-Item $dir -ItemType directory
    }
}

function Export-AppPool
{
    [CmdletBinding()]
    param
    (
        [string] $ServerHost,
        [Parameter(Mandatory = $true)]
        [string] $OutputFilename
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    CreateOutputDirectory $OutputFilename
    $xml = GetAppCmdOutput $ServerHost @('list', 'apppool', '/config', '/xml')
    $xml | Set-Content $OutputFilename
}

function Export-Site
{
    [CmdletBinding()]
    param
    (
        [Parameter(HelpMessage = 'Hostname of the server with IIS site configured.')]
        [string] $ServerHost,
        [Parameter(Mandatory = $true)]
        [string] $OutputFilename
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    CreateOutputDirectory $OutputFilename
    $xml = GetAppCmdOutput $ServerHost @('list', 'site', '/config', '/xml')
    $xml | Set-Content $OutputFilename
}

function Install-Iis
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "",
                                                       Scope="Function", Target="*")]

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $ServerHost,
        [switch] $ManagementService,
        [switch] $WebDeploy,
        [switch] $UrlRewrite,
        [switch] $Arr
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $session = Start-RemoteSession $ServerHost

    Invoke-Command -Session $session -ScriptBlock `
        {
            # Get available features, they can differ in Windows Server 2008 and 2012.
            $features = Get-WindowsFeature Web-Server, Web-Asp-Net45, Web-Asp-Net
            Add-WindowsFeature $features
        }
    Write-Information 'IIS is set up successfully.'

    if ($ManagementService)
    {
        Install-WebManagementService -Session $session
    }

    if ($WebDeploy)
    {
        Install-WebDeploy -Session $session
    }

    if ($UrlRewrite)
    {
        Install-UrlRewrite -Session $session
    }

    if ($Arr)
    {
        Install-Arr -Session $session
    }

    Invoke-Command -Session $session -ScriptBlock `
        {
            if (Get-WebSite -Name 'Default Web Site')
            {
                Remove-WebSite -Name 'Default Web Site'
                Get-ChildItem C:\inetpub\wwwroot -Recurse | Remove-Item -Recurse
                Write-Information 'Default Web Site is deleted.'
            }
        }

    Remove-PSSession $session
}

function Install-WebManagementService
{
    [CmdletBinding(DefaultParameterSetName = 'Server')]
    param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'Server')]
        [string] $ServerHost,
        [Parameter(Mandatory = $true, ParameterSetName = 'Session')]
        [System.Management.Automation.Runspaces.PSSession] $Session
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if ($ServerHost)
    {
        $Session = Start-RemoteSession $ServerHost
    }

    Invoke-Command -Session $Session -ScriptBlock `
        {
            # Install web management service.
            Add-WindowsFeature Web-Mgmt-Service
            # Enable remote access.
            Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WebManagement\Server -Name EnableRemoteManagement -Value 1
            # Change service startup type to automatic.
            Set-Service WMSVC -StartupType Automatic

            # Replace WMSvc-HOST with HOST certificate. It should be generated already during WinRM configuration.
            Import-Module WebAdministration
            $hostname = [System.Net.Dns]::GetHostByName('localhost').Hostname
            $thumbprint = Get-ChildItem -Path Cert:\LocalMachine\My |
                Where-Object { $_.Subject -EQ "CN=$hostname" } |
                Select-Object -First 1 -ExpandProperty Thumbprint
            if (!$thumbprint)
            {
                "SSL certificate for $hostname host is not found."
            }
            if (Test-Path IIS:\SslBindings\0.0.0.0!8172)
            {
                Remove-Item -Path IIS:\SslBindings\0.0.0.0!8172
            }
            Get-Item -Path "Cert:\LocalMachine\My\$thumbprint" | New-Item -Path IIS:\SslBindings\0.0.0.0!8172

            # Start web management service.
            Start-Service WMSVC
        }

    Write-Information 'Web management service is installed and configured.'

    if ($ServerHost)
    {
        Remove-PSSession $Session
    }
}

function Install-WebDeploy
{
    [CmdletBinding(DefaultParameterSetName = 'Server')]
    param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'Server')]
        [string] $ServerHost,
        [Parameter(Mandatory = $true, ParameterSetName = 'Session')]
        [System.Management.Automation.Runspaces.PSSession] $Session
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if ($ServerHost)
    {
        $Session = Start-RemoteSession $ServerHost
    }

    Invoke-Command -Session $Session -ScriptBlock `
        {
            # 1.1 = {0F37D969-1260-419E-B308-EF7D29ABDE20}
            # 2.0 = {5134B35A-B559-4762-94A4-FD4918977953}
            # 3.5 = {3674F088-9B90-473A-AAC3-20A00D8D810C}
            $webDeploy36Guid = '{ED4CC1E5-043E-4157-8452-B5E533FE2BA1}'
            $installedProduct = Get-CimInstance -Class Win32_Product -Filter "IdentifyingNumber = '$webDeploy36Guid'"

            if ($installedProduct)
            {
                'WebDeploy is installed already.'
            }
            else
            {
                $webDeploy36Url = 'https://download.microsoft.com/download/0/1/D/01DC28EA-638C-4A22-A57B-4CEF97755C6C/WebDeploy_amd64_en-US.msi'
                $tempPath = "$env:TEMP\" + [guid]::NewGuid()

                'Downloading WebDeploy installer...'
                Invoke-WebRequest $webDeploy36Url -OutFile $tempPath -ErrorAction Stop
                'OK'

                msiexec.exe /i $tempPath ADDLOCAL=MSDeployFeature,MSDeployUIFeature,DelegationUIFeature,MSDeployWMSVCHandlerFeature | Out-Null
                if ($LASTEXITCODE)
                {
                    throw 'MsiExec failed.'
                }

                Remove-Item $tempPath -ErrorAction SilentlyContinue
                'WebDeploy is installed.'
            }
        }

    if ($ServerHost)
    {
        Remove-PSSession $Session
    }
}

function Install-UrlRewrite
{
    [CmdletBinding(DefaultParameterSetName = 'Server')]
    param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'Server')]
        [string] $ServerHost,
        [Parameter(Mandatory = $true, ParameterSetName = 'Session')]
        [System.Management.Automation.Runspaces.PSSession] $Session
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if ($ServerHost)
    {
        $Session = Start-RemoteSession $ServerHost
    }

    Invoke-Command -Session $Session -ScriptBlock `
        {
            $urlRewrite20Guid = '{08F0318A-D113-4CF0-993E-50F191D397AD}'
            $installedProduct = Get-CimInstance -Class Win32_Product -Filter "IdentifyingNumber = '$urlRewrite20Guid'"

            if ($installedProduct)
            {
                'URL Rewrite Module is installed already.'
            }
            else
            {
                $urlRewrite20Url = 'http://download.microsoft.com/download/C/9/E/C9E8180D-4E51-40A6-A9BF-776990D8BCA9/rewrite_amd64.msi'
                $tempPath = "$env:TEMP\" + [guid]::NewGuid()

                'Downloading URL Rewrite Module installer...'
                Invoke-WebRequest $urlRewrite20Url -OutFile $tempPath -ErrorAction Stop
                'OK'

                msiexec.exe /i $tempPath ADDLOCAL=ALL | Out-Null
                if ($LASTEXITCODE)
                {
                    throw 'MsiExec failed.'
                }

                Remove-Item $tempPath
                'URL Rewrite Module is installed.'
            }
        }

    if ($ServerHost)
    {
        Remove-PSSession $Session
    }
}

<#
.NOTES
Msiexec supports HTTP links.
#>
function Install-MsiPackage
{
    [CmdletBinding(DefaultParameterSetName = 'Server')]
    param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'Server')]
        [string] $ServerHost,
        [Parameter(Mandatory = $true, ParameterSetName = 'Session')]
        [System.Management.Automation.Runspaces.PSSession] $Session,
        [Parameter(Mandatory = $true)]
        [string] $ProductName,
        [Parameter(Mandatory = $true)]
        [string] $ProductId,
        [Parameter(Mandatory = $true)]
        [string] $MsiPath,
        [string] $LocalFeatures = 'ALL'
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if ($ServerHost)
    {
        $Session = Start-RemoteSession $ServerHost
    }

    Invoke-Command -Session $Session -ScriptBlock `
        {
            $installedProduct = Get-CimInstance -Class Win32_Product -Filter "IdentifyingNumber = '$using:ProductId'"

            if ($installedProduct)
            {
                Write-Information "$using:ProductName is installed already."
            }
            else
            {
                msiexec.exe /i $using:MsiPath ADDLOCAL=$using:LocalFeatures | Out-Null
                if ($LASTEXITCODE)
                {
                    throw 'MsiExec failed.'
                }

                Write-Information "$using:ProductName is installed."
            }
        }

    if ($ServerHost)
    {
        Remove-PSSession $Session
    }
}

function Import-SslCertificate
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $ServerHost,
        [Parameter(Mandatory = $true)]
        [string] $CertificatePath,
        [Parameter(Mandatory = $true)]
        [System.Security.SecureString] $CertificatePassword
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $Session = Start-RemoteSession $ServerHost

    $name = (Get-Item $CertificatePath).Name
    $tempPath = Get-RemoteTempPath $Session
    Copy-Item -Path $CertificatePath -Destination $tempPath -ToSession $Session

    Invoke-Command -Session $Session -ScriptBlock `
        {
            Import-PfxCertificate "$using:tempPath\$using:name" -CertStoreLocation 'Cert:\LocalMachine\My' -Password $using:CertificatePassword

            Remove-Item $using:tempPath -Recurse -Force
        }

    Remove-PSSession $Session
}

<#
.SYNOPSIS
Installs Application Request Routing 3.0.

.PARAMETER ServerHost
Server hostname.

.PARAMETER Session
Open WinRM session.
#>
function Install-Arr
{
    [CmdletBinding(DefaultParameterSetName = 'Server')]
    param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'Server')]
        [string] $ServerHost,
        [Parameter(Mandatory = $true, ParameterSetName = 'Session')]
        [System.Management.Automation.Runspaces.PSSession] $Session
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if ($ServerHost)
    {
        $Session = Start-RemoteSession $ServerHost
    }

    Install-MsiPackage -Session $Session -ProductName 'Application Request Routing 3.0' `
        -ProductId '{279B4CB0-A213-4F94-B224-19D6F5C59942}' `
        -MsiPath 'http://download.microsoft.com/download/E/9/8/E9849D6A-020E-47E4-9FD0-A023E99B54EB/requestRouter_amd64.msi'

    if ($ServerHost)
    {
        Remove-PSSession $Session
    }
}
