function Get-VersionTemplate([string] $fileName)
{
    $lines = Get-Content $fileName
    $regex = [regex] '<ApplicationVersion>(\d+\.\d+\.\d+\.).*</ApplicationVersion>'
    $regex.Match($lines)[0].Groups[1].Value
}

function Update-ApplicationRevision([string] $fileName)
{
    $regex = [regex] "(<ApplicationRevision>)(\d+)(</ApplicationRevision>)"
    $lines = Get-Content $fileName
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

    $lines | Out-File $fileName -Encoding utf8
    $version
}

# NOTE: Copy ..\artifacts\publish.htm.template file to project directory and replace ApplicationName.
function Invoke-ProjectBuildAndPublish([string] $projectDir, [string] $projectName, [string] $publishDir, [string] $installUrl)
{
    if (Test-Path $publishDir)
    {
        Remove-Item $publishDir -Recurse -ErrorAction Stop
    }

    msbuild.exe '/m' "$projectDir\$projectName.csproj" '/t:Publish' '/p:Configuration=Release' "/p:PublishDir=$publishDir\" "/p:InstallUrl=$installUrl" '/verbosity:normal'
    if ($LASTEXITCODE)
    {
        throw "Build failed."
    }

    Copy-Item "$projectDir\publish.htm.template" "$publishDir\publish.htm"
    Remove-Item "$publishDir\*.exe" -Exclude "setup.exe"
}

function Update-PublishVersion([string] $publishDir, [string] $version)
{
    (Get-Content "$publishDir\publish.htm") -Replace "{VERSION}", $version | Out-File "$publishDir\publish.htm" -Encoding utf8
}

function Invoke-FullPublish([string] $projectDir, [string] $projectName, [string] $publishDir, [string] $installUrl)
{
    $revision = Update-ApplicationRevision "$projectDir\$projectName.csproj"
    $template = Get-VersionTemplate "$projectDir\$projectName.csproj"
    $version = $template + $revision

    Invoke-ProjectBuildAndPublish $projectDir $projectName $publishDir $installUrl
    Update-PublishVersion $publishDir $version
    Write-Host "Published $projectName $version." -ForegroundColor Green
}
