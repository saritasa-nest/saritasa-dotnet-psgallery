$msdeployPath = "$env:ProgramFiles\IIS\Microsoft Web Deploy V3\"

function Set-MsdeployPath([string] $path)
{
    $script:msdeployPath = $path
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

function Start-AppPool([string] $serverHost, [string] $siteName, [string] $application)
{
    'Starting app pool...'
    &"$msdeployPath\msdeploy.exe" '-verb:sync' '-source:recycleApp' "-dest:recycleApp=`"$siteName/$application`",recycleMode=`"StartAppPool`",computername=$serverHost"
}

function Stop-AppPool([string] $serverHost, [string] $siteName, [string] $application)
{
    'Stopping app pool...'
    &"$msdeployPath\msdeploy.exe" '-verb:sync' '-source:recycleApp' "-dest:recycleApp=`"$siteName/$application`",recycleMode=`"StopAppPool`",computername=$serverHost"
}

function Invoke-WebDeployment([string] $packagePath, [string] $serverHost, [string] $siteName, [string] $application)
{
    "Deploying $packagePath to $serverHost/$application..."
    &"$msdeployPath\msdeploy.exe" "-source:package=$packagePath" `
        "-dest:auto,computerName=`"https://$serverHost:8172/msdeploy.axd?site=$siteName`",includeAcls=`"False`"" `
        '-verb:sync' '-disableLink:AppPoolExtension' '-disableLink:ContentExtension' '-disableLink:CertificateExtension' `
        '-allowUntrusted' "-setParam:name='IIS Web Application Name',value='$siteName/$application'"
}
