$msdeployPath = "$env:ProgramFiles\IIS\Microsoft Web Deploy V3"
$username = ''
$password = ''
$credentials = ''

function Set-MsdeployPath([string] $path)
{
    $script:msdeployPath = $path
}

# Leave $username and $password empty for NTLM.
# For NTLM support execute on server:
# Set-ItemProperty HKLM:Software\Microsoft\WebManagement\Server WindowsAuthenticationEnabled 1
# Restart-Service WMSVC
# https://blogs.msdn.microsoft.com/carlosag/2011/12/13/using-windows-authentication-with-web-deploy-and-wmsvc/
function Set-WebDeployCredentials([string] $username, [string] $password)
{
    $script:username = $path
    $script:password = $path
    
    $script:credentials = ''
    if ($username)
    {
        $script:credentials = "userName=$username,password=$password,authType=basic"
    }
    else
    {
        $script:credentials = "authType='ntlm'"
    }
}

function Assert-WebDeployCredentials()
{
    if (!$credentials)
    {
        throw 'Credentials are not set.'
    }
}

function Invoke-PackageBuild([string] $projectPath,
                             [string] $packagePath,
                             [string] $configuration = 'Release',
                             [string] $platform = 'AnyCPU',
                             [bool] $precompile = $true,
                             [string[]] $buildParams)
{
    $basicBuildParams = ('/m', '/t:Package', "/p:Configuration=$configuration",
        '/p:IncludeSetAclProviderOnDestination=False', "/p:PrecompileBeforePublish=$precompile",
        "/p:Platform=$platform", "/p:PackageLocation=$packagePath")
    msbuild.exe $projectPath $allBuildParams $basicBuildParams $buildParams
}

# The recycleApp provider should be delegated to WDeployAdmin.
function Start-AppPool([string] $serverHost, [string] $siteName, [string] $application)
{
    Assert-WebDeployCredentials
    'Starting app pool...'
    
    $destArg = "-dest:recycleApp='$siteName/$application',recycleMode='StartAppPool'," +
        "computername=https://${serverHost}:8172/msdeploy.axd?site=$siteName," + $credentials
    $args = @('-verb:sync', '-source:recycleApp', $destArg)
    
    $result = Start-Process -NoNewWindow -Wait -PassThru "$msdeployPath\msdeploy.exe" $args
    if ($result.ExitCode)
    {
        throw 'Msdeploy failed.'
    }
}

# The recycleApp provider should be delegated to WDeployAdmin.
function Stop-AppPool([string] $serverHost, [string] $siteName, [string] $application, [string] $username, [string] $password)
{
    Assert-WebDeployCredentials
    'Stopping app pool...'

    $destArg = "-dest:recycleApp='$siteName/$application',recycleMode='StopAppPool'," +
        "computername=https://${serverHost}:8172/msdeploy.axd?site=$siteName," + $credentials
    $args = @('-verb:sync', '-source:recycleApp', $destArg)
    
    $result = Start-Process -NoNewWindow -Wait -PassThru "$msdeployPath\msdeploy.exe" $args
    if ($result.ExitCode)
    {
        throw 'Msdeploy failed.'
    }
}

# The recycleApp provider should be delegated to WDeployConfigWriter.
function Invoke-WebDeployment([string] $packagePath, [string] $serverHost, [string] $siteName, [string] $application)
{
    "Deploying $packagePath to $serverHost/$application..."
    
    "https://${serverHost}:8172/msdeploy.axd"
    
    $destArg = 
    $args = @("-source:package=$packagePath",
              ("-dest:auto,computerName='https://${serverHost}:8172/msdeploy.axd?site=$siteName',includeAcls='False'," + $credentials),
              '-verb:sync', '-disableLink:AppPoolExtension', '-disableLink:ContentExtension', '-disableLink:CertificateExtension',
              '-allowUntrusted', "-setParam:name='IIS Web Application Name',value='$siteName/$application")
    
    $result = Start-Process -NoNewWindow -Wait -PassThru "$msdeployPath\msdeploy.exe" $args 
    if ($result.ExitCode)
    {
        throw 'Msdeploy failed.'
    }
}
