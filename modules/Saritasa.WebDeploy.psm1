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
