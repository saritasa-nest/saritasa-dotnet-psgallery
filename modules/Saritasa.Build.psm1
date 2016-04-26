function Initialize-BuildVariables()
{
    $scriptPath = ($env:VS150COMNTOOLS, $env:VS140COMNTOOLS, $env:VS120COMNTOOLS, $env:VS110COMNTOOLS -ne $null)[0] + 'vsvars32.bat'
    Invoke-Environment $scriptPath
}

function Invoke-NugetRestore([string] $solutionPath)
{
    $nugetExePath = "$PSScriptRoot\nuget.exe"
    
    if (!(Test-Path $nugetExePath))
    {
        Invoke-WebRequest 'http://nuget.org/nuget.exe' -OutFile $nugetExePath
    }
    
    &$nugetExePath 'restore' $solutionPath
}

function Invoke-SolutionBuild([string] $solutionPath, [string] $configuration)
{
    msbuild.exe $solutionPath '/m' '/t:Build' "/p:Configuration=$configuration" '/verbosity:normal'
    if ($LASTEXITCODE)
    {
        throw "Build failed."
    }
}

# Based on Invoke-Environment script.
# https://github.com/nightroman/PowerShelf/blob/master/Invoke-Environment.ps1
# Copyright (c) 2012-2016 Roman Kuzmin
# Apache License, Version 2.0
function Invoke-Environment([string] $command, [switch] $output, [switch] $force)
{
    $stream = if ($output) { ($temp = [IO.Path]::GetTempFileName()) } else { 'nul' }
    $operator = if ($force) {'&'} else {'&&'}

    foreach($_ in cmd /c " `"$command`" > `"$stream`" 2>&1 $operator SET")
    {   
        if ($_ -match '^([^=]+)=(.*)')
        {
            [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
        }
    }

    if ($output)
    {
        Get-Content -LiteralPath $temp
        Remove-Item -LiteralPath $temp
    }
}
