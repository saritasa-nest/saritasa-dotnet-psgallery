$credential = $null

function Set-RemoteManagementCredentials
{
    param
    (
        [string] $Username,
        [string] $Password,
        [System.Management.Automation.PSCredential] $Credential
    )

    if ($Username)
    {
        $script:credential = New-Object System.Management.Automation.PSCredential($Username, (ConvertTo-SecureString $Password -AsPlainText -Force))
    }
    else
    {
        $script:credential = $Credential
    }
}

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
    
    if ($ServerHost) # Remote server.
    {
        if (!$credential)
        {
            throw 'Credentials are not set.'
        }
        
        $session = New-PSSession -UseSSL -Credential $credential $ServerHost

        Invoke-Command -Session $session -ScriptBlock { $using:config | &$using:appCmd $using:Arguments }

        Remove-PSSession $session
    }
    else # Local server.
    {
        Invoke-Command { $config | &$appCmd $Arguments }
        $exitCode = $LASTEXITCODE
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
        if (!$credential)
        {
            throw 'Credentials are not set.'
        }
        
        $session = New-PSSession -UseSSL -Credential $credential $ServerHost

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
    
    $output
}

function Import-AppPools
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $ServerHost,
        [Parameter(Mandatory = $true)]
        [string] $ConfigFilename
    )

    ExecuteAppCmd $ServerHost $ConfigFilename @('add', 'apppool', '/in') $false
}

function Import-Sites
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $ServerHost,
        [Parameter(Mandatory = $true)]
        [string] $ConfigFilename
    )

    ExecuteAppCmd $ServerHost $ConfigFilename @('add', 'site', '/in') $false
}

function Export-AppPools
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $ServerHost,
        [Parameter(Mandatory = $true)]
        [string] $OutputFilename
    )
    
    $xml = GetAppCmdOutput $ServerHost @('list', 'apppool', '/config', '/xml')
    $xml | Set-Content $OutputFilename
}

function Export-Sites
{
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = 'Hostname of the server with IIS site configured.')]
        [string] $ServerHost,
        [Parameter(Mandatory = $true)]
        [string] $OutputFilename
    )

    $xml = GetAppCmdOutput $ServerHost @('list', 'site', '/config', '/xml')
    $xml | Set-Content $OutputFilename
}

function StartSession
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $ServerHost,
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential] $Credential
    )
    
    New-PSSession -UseSSL -Credential $Credential $ServerHost
}

function Install-Iis
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $ServerHost,
        [switch] $ManagementService,
        [switch] $WebDeploy
    )
    
    $session = StartSession $ServerHost $credential
    
    Invoke-Command -Session $session -ScriptBlock { Add-WindowsFeature Web-Server }
    Write-Host 'IIS is set up successfully.'

    if ($ManagementService)
    {
        Install-WebManagementService -Session $session
    }
    
    if ($WebDeploy)
    {
        Install-WebDeploy -Session $session
    }
    
    Remove-PSSession $session
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
        $Session = StartSession $ServerHost $credential
    }
    
    $Session
}

function Install-WebManagementService
{
    param
    (
        [string] $ServerHost,
        [System.Management.Automation.Runspaces.PSSession] $Session
    )

    $Session = CheckSession $ServerHost $Session
    
    Invoke-Command -Session $session -ScriptBlock `
        {
            # Install web management service.
            Add-WindowsFeature Web-Mgmt-Service
            # Enable remote access.
            Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WebManagement\Server -Name EnableRemoteManagement -Value 1
            # Change service startup type to automatic.
            Set-Service WMSVC -StartupType Automatic
            
            # Replace WMSvc-HOST with HOST certificate. It should be generated already during WinRM configuration.
            Import-Module WebAdministration
            $hostname = $env:COMPUTERNAME
            $thumbprint = Get-ChildItem -Path Cert:\LocalMachine\My | where { $_.Subject -EQ "CN=$hostname" } | select -ExpandProperty Thumbprint
            if ($thumbprint)
            {
                'SSL certificate for $hostname host is not found.'
            }            
            if (Test-Path IIS:\SslBindings\0.0.0.0!8172)
            {
                Remove-Item -Path IIS:\SslBindings\0.0.0.0!8172
            }
            Get-Item -Path "Cert:\LocalMachine\My\$thumbprint" | New-Item -Path IIS:\SslBindings\0.0.0.0!8172

            # Start web management service.
            Start-Service WMSVC
        }
    Write-Host 'Web management service is installed and configured.'
}

function Install-WebDeploy
{
    param
    (
        [string] $ServerHost,
        [System.Management.Automation.Runspaces.PSSession] $Session
    )
    
    $Session = CheckSession $ServerHost $Session
    
    Invoke-Command -Session $session -ScriptBlock `
        {
            # 1.1 = {0F37D969-1260-419E-B308-EF7D29ABDE20}
            # 2.0 = {5134B35A-B559-4762-94A4-FD4918977953}
            # 3.5 = {3674F088-9B90-473A-AAC3-20A00D8D810C}
            $webDeploy36Guid = '{ED4CC1E5-043E-4157-8452-B5E533FE2BA1}'
            $installedProduct = Get-WmiObject -Class Win32_Product -Filter "IdentifyingNumber = '{ED4CC1E5-043E-4157-8452-B5E533FE2BA1}'"
            
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
                
                msiexec.exe /i $tempPath ADDLOCAL=MSDeployFeature,MSDeployUIFeature,DelegationUIFeature,MSDeployWMSVCHandlerFeature
                if ($LASTEXITCODE)
                {
                    'MsiExec failed.'
                }
        
                Remove-Item $tempPath
                'WebDeploy is installed.'
            }
        }
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
    param
    (
        [string] $Path,
        [string] $ServerHost,
        [System.Management.Automation.Runspaces.PSSession] $Session,
        [hashtable] $Parameters
    )
    
    $Session = CheckSession $ServerHost $Session
    
    $scriptContent = Get-Content $Path -Raw
    $scriptParams = &{$args} @Parameters
    $sb = [scriptblock]::create("&{ $scriptContent } $scriptParams")
    
    Invoke-Command -Session $Session -ScriptBlock $sb
}
