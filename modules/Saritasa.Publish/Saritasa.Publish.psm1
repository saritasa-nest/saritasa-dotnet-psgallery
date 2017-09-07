function Get-VersionTemplate
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $Filename
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $lines = Get-Content $Filename
    $regex = [regex] '<ApplicationVersion>(\d+\.\d+\.\d+\.).*</ApplicationVersion>'
    $regex.Match($lines)[0].Groups[1].Value
}

function Set-ApplicationVersion
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $Filename,
        [Parameter(Mandatory = $true)]
        [string] $Version
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $regex = [regex] '(<ApplicationVersion>)(.*)(</ApplicationVersion>)'

    $lines = Get-Content $Filename

    for ($i = 0; $i -lt $lines.Length; $i++)
    {
        $l = $lines[$i]
        if ($regex.IsMatch($l))
        {
            $lines[$i] = $regex.Replace($l, "`${1}$Version`$3")
            break
        }
    }

    $lines | Out-File $Filename -Encoding utf8
}

function Update-ApplicationRevision
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $Filename
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $regex = [regex] "(<ApplicationRevision>)(\d+)(</ApplicationRevision>)"
    $lines = Get-Content $Filename
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

    $lines | Out-File $Filename -Encoding utf8
    $version
}

<#
.SYNOPSIS

.DESCRIPTION
Copy publish.htm.template file to project directory and replace ApplicationName.
#>
function Invoke-ProjectBuildAndPublish
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $ProjectFilename,
        [Parameter(Mandatory = $true)]
        [string] $PublishDir,
        [string] $InstallUrl,
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

function Update-PublishVersion
{
    [CmdletBinding()]
    param
    (
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
Run full publish: invoke project build and publish, set and update project's version.
#>
function Invoke-FullPublish
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $ProjectFilename,
        [Parameter(Mandatory = $true)]
        [string] $PublishDir,
        [string] $InstallUrl,
        [string] $Version,
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
Invoke build of database project and run migratoins for database.

.EXAMPLE
Update-VariablesInFile -Path $profilePath -Variables @{ DatabasePassword = $DatabasePassword }
Invoke-DatabaseProjectPublish "$src\Saritasa.Crm.Database\Saritasa.Crm.Database.sqlproj" $Configuration -ProfilePath $profilePath -Target 'Build;Publish'
Update password in build profile and run publish.
#>
function Invoke-DatabaseProjectPublish
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = 'Path to sql server database project.')]
        [string] $ProjectPath,
        [Parameter(HelpMessage = 'Build configuration (Release, Debug, etc.)')]
        [string] $Configuration = 'Release',
        [Parameter(HelpMessage = 'Build target (Deploy, Publish, etc.)')]
        [string] $Target = 'Publish',
        [Parameter(Mandatory = $true, HelpMessage = 'Path to xml profile file.')]
        [string] $ProfilePath
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    Invoke-ProjectBuild $ProjectPath $Configuration $Target @("/p:SqlPublishProfilePath=$($ProfilePath)")
}
