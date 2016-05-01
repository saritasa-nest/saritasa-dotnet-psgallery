function Get-VersionTemplate
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $FileName
    )

    $lines = Get-Content $FileName
    $regex = [regex] '<ApplicationVersion>(\d+\.\d+\.\d+\.).*</ApplicationVersion>'
    $regex.Match($lines)[0].Groups[1].Value
}

function Update-ApplicationRevision
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $FileName
    )

    $regex = [regex] "(<ApplicationRevision>)(\d+)(</ApplicationRevision>)"
    $lines = Get-Content $FileName
    $version = 0

    for ($i = 0; $i -lt $lines.Length; $i++)
    {
        $l = $lines[$i]
        if ($regex.IsMatch($l))
        {
            $version = [int]$regex.Match($l).Groups[2].Value + 1
            $lines[$i] = $regex.Replace($l, "`${1}$version`$3")
        }
    }

    $lines | Out-File $FileName -Encoding utf8
    $version
}

<#
.SYNOPSIS

.DESCRIPTION
Copy publish.htm.template file to project directory and replace ApplicationName.
#>
function Invoke-ProjectBuildAndPublish
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $ProjectDir,
        [Parameter(Mandatory = $true)]
        [string] $ProjectName,
        [Parameter(Mandatory = $true)]
        [string] $PublishDir,
        [Parameter(Mandatory = $true)]
        [string] $InstallUrl)

    if (Test-Path $PublishDir)
    {
        Remove-Item $PublishDir -Recurse -ErrorAction Stop
    }

    msbuild.exe '/m' "$ProjectDir\$ProjectName.csproj" '/t:Publish' '/p:Configuration=Release' "/p:PublishDir=$PublishDir\" "/p:InstallUrl=$InstallUrl" '/verbosity:normal'
    if ($LASTEXITCODE)
    {
        throw "Build failed."
    }

    Copy-Item "$ProjectDir\publish.htm.template" "$publishDir\publish.htm"
    Remove-Item "$publishDir\*.exe" -Exclude "setup.exe"
}

function Update-PublishVersion
{
    param
    {
        [Parameter(Mandatory = $true)]
        [string] $PublishDir,
        [Parameter(Mandatory = $true)]
        [string] $Version
    }

    (Get-Content "$publishDir\publish.htm") -Replace "{VERSION}", $Version | Out-File "$PublishDir\publish.htm" -Encoding utf8
}

function Invoke-FullPublish
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $ProjectDir,
        [Parameter(Mandatory = $true)]
        [string] $ProjectName,
        [Parameter(Mandatory = $true)]
        [string] $PublishDir,
        [Parameter(Mandatory = $true)]
        [string] $InstallUrl
    )

    $revision = Update-ApplicationRevision "$ProjectDir\$ProjectName.csproj"
    $template = Get-VersionTemplate "$ProjectDir\$ProjectName.csproj"
    $version = $template + $revision

    Invoke-ProjectBuildAndPublish $ProjectDir $ProjectName $PublishDir $InstallUrl
    Update-PublishVersion $PublishDir $version
    Write-Host "Published $ProjectName $version to `"$PublishDir`" directory." -ForegroundColor Green
}
