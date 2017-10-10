<#
.SYNOPSIS
Retrieves the ApplicationVersion info defined in the file.
#>
function Get-VersionTemplate
{
    [CmdletBinding()]
    param
    (
        # Path to file to process.
        [Parameter(Mandatory = $true)]
        [string] $Filename
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $lines = Get-Content $Filename
    $regex = [regex] '<ApplicationVersion>(\d+\.\d+\.\d+\.).*</ApplicationVersion>'
    $regex.Match($lines)[0].Groups[1].Value
}

<#
.SYNOPSIS
Sets the ApplicationVersion information in a XML file.

.EXAMPLE
Set-ApplicationVersion ..\src\MyApp\MyApp.csproj 6.5.5
#>
function Set-ApplicationVersion
{
    [CmdletBinding()]
    param
    (
        # File path to process.
        [Parameter(Mandatory = $true)]
        [string] $Filename,
        # Version info to be set in ApplicationVersion item.
        [Parameter(Mandatory = $true)]
        [string] $Version
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $regex = [regex] '(\s*<ApplicationVersion>)[^<]+(</ApplicationVersion>\s*)'

    $lines = Get-Content $Filename

    # If file contains only one line, the result will be a string, not string array.
    if ($lines -is [string])
    {
        $lines = @($lines)
    }

    for ($i = 0; $i -lt $lines.Length; $i++)
    {
        $l = $lines[$i]
        if ($regex.IsMatch($l))
        {
            $lines[$i] = $regex.Replace($l, "`${1}$Version`$2")
            break
        }
    }

    $lines | Out-File $Filename -Encoding utf8 -NoNewline
}

<#
.SYNOPSIS
Updates the ApplicationRevision information a file by incrementing it and returns the updated revision value.

.NOTES
If ApplicationRevision information is not found in the file, the returned value will be 0.
#>
function Update-ApplicationRevision
{
    [CmdletBinding()]
    param
    (
        # File path to process.
        [Parameter(Mandatory = $true)]
        [string] $Filename
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $regex = [regex] '(\s*<ApplicationRevision>)(\d+)(</ApplicationRevision>\s*)'
    $lines = Get-Content $Filename

    # If file contains only one line, the result will be a string, not string array
    if ($lines -is [string])
    {
        $lines = @($lines)
    }
    $version = 0

    for ($i = 0; $i -lt $lines.Length; $i++)
    {
        $l = $lines[$i]
        if ($regex.IsMatch($l))
        {
            $version = [int]$regex.Match($l).Groups[2].Value + 1
            $lines[$i] = $regex.Replace($l, "`${1}$version`$3")
            break
        }
    }

    $lines | Out-File $Filename -Encoding utf8 -NoNewline
    $version
}

<#
.SYNOPSIS
Publishes the project and copies the publish.htm file to destination directory.

.PARAMETER PublishDir
Directory to output the publish results.
Will be cleared before publish.

.NOTES
publish.htm.template file should exist in the same directory where ProjectFilename file located.
#>
function Invoke-ProjectBuildAndPublish
{
    [CmdletBinding()]
    param
    (
        # Path to project file to be published.
        [Parameter(Mandatory = $true)]
        [string] $ProjectFilename,
        [Parameter(Mandatory = $true)]
        [string] $PublishDir,
        # InstallUrl property to be passed to MSBuild task.
        [string] $InstallUrl,
        # Additional build params to be passed for MSBuild.
        [string[]] $BuildParams
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if (Test-Path $PublishDir)
    {
        Remove-Item $PublishDir -Recurse -ErrorAction Stop
    }

    $params = @("/p:PublishDir=$PublishDir\") + $BuildParams

    if ($InstallUrl)
    {
        $params += "/p:InstallUrl=$InstallUrl"
    }

    Invoke-ProjectBuild -ProjectPath $ProjectFilename -Configuration 'Release' -Target 'Publish' -BuildParams $params

    $projectDir = Split-Path $ProjectFilename

    Copy-Item "$projectDir\publish.htm.template" "$PublishDir\publish.htm"
    Remove-Item "$PublishDir\*.exe" -Exclude "setup.exe"
}

<#
.SYNOPSIS
Update the Version information in publish.htm file.

.EXAMPLE
Update-PublishVersion C:\publish\myapp 4.4.2

.NOTES
In publish.htm file the {VERSION} string will be replaced with provided Version value.
#>
function Update-PublishVersion
{
    [CmdletBinding()]
    param
    (
        # Directory where to search for publish.htm file.
        [Parameter(Mandatory = $true)]
        [string] $PublishDir,
        [Parameter(Mandatory = $true)]
        [string] $Version
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    (Get-Content "$publishDir\publish.htm") -Replace "{VERSION}", $Version | Out-File "$PublishDir\publish.htm" -Encoding utf8
}

<#
.SYNOPSIS
Publishes the ClickOnce application. Runs full publish: invoke project build and publish, set and update project's version.

.PARAMETER InstallUrl
Location where users will install the application from
(see InstallUrl parameter description for msbuild cli for more information).

.PARAMETER Version
Version to be assigned to the application.
If omitted, it will be automatically calculated by incrementing the revision number.

.EXAMPLE
Invoke-FullPublish ..\src\myapp\myapp.csproj C:\publish\myapp -Version 4.4.2
#>
function Invoke-FullPublish
{
    [CmdletBinding()]
    param
    (
        # Path to project file to be published.
        [Parameter(Mandatory = $true)]
        [string] $ProjectFilename,
        # Directory to which the result application should be published.
        [Parameter(Mandatory = $true)]
        [string] $PublishDir,
        [string] $InstallUrl,
        [string] $Version,
        # Additional build params to be passed for msbuild.
        [string[]] $BuildParams
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if ($Version)
    {
        Set-ApplicationVersion $ProjectFilename $Version
        $newVersion = $Version
    }
    else
    {
        $revision = Update-ApplicationRevision $ProjectFilename
        $template = Get-VersionTemplate $ProjectFilename
        $newVersion = $template + $revision
    }

    $projectName = (Get-Item $ProjectFilename).BaseName

    Invoke-ProjectBuildAndPublish $ProjectFilename $PublishDir $InstallUrl -BuildParams $BuildParams
    Update-PublishVersion $PublishDir $newVersion
    Write-Information "Published $projectName $newVersion to `"$PublishDir`" directory."
}

<#
.SYNOPSIS
Invoke build of database project and run migrations for database.

.EXAMPLE
Update-VariablesInFile -Path $profilePath -Variables @{ DatabasePassword = $DatabasePassword }
Invoke-DatabaseProjectPublish "$src\Saritasa.Crm.Database\Saritasa.Crm.Database.sqlproj" $Configuration -ProfilePath $profilePath -Target 'Build;Publish'
Update password in build profile and run publish.

.EXAMPLE
Invoke-DatabaseProjectPublish ..\src\MyApp.Database\MyApp.Database.sqlproj -ProfilePath ..\src\MyApp.Database\PublishProfiles\Production.publish.xml
#>
function Invoke-DatabaseProjectPublish
{
    [CmdletBinding()]
    param
    (
        # Path to SQL Server database project.
        [Parameter(Mandatory = $true)]
        [string] $ProjectPath,
        # Build configuration (Release, Debug, etc.)
        [string] $Configuration = 'Release',
        # Build target (Deploy, Publish, etc.)
        [string] $Target = 'Publish',
        # Path to XML profile file.
        [Parameter(Mandatory = $true)]
        [string] $ProfilePath
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    Invoke-ProjectBuild $ProjectPath $Configuration $Target @("/p:SqlPublishProfilePath=$($ProfilePath)")
}
