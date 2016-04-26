function Initialize-BuildVariables()
{
    $registryRoot = 'HKLM:\SOFTWARE\Microsoft\MSBuild\ToolsVersions\'
    if (Test-Path "$registryRoot\14.0")
    {
        $path = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\MSBuild\ToolsVersions\14.0).MSBuildToolsPath
        $env:PATH = "$path;$env:PATH"
    }
    else
    {
        $scriptPath = ($env:VS150COMNTOOLS, $env:VS140COMNTOOLS, $env:VS120COMNTOOLS, $env:VS110COMNTOOLS -ne $null)[0] + 'vsvars32.bat'
        Invoke-Environment $scriptPath
    }
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

# Update version numbers of AssemblyInfo.cs and AssemblyInfo.vb.
# Based on SetVersion script.
# http://www.luisrocha.net/2009/11/setting-assembly-version-with-windows.html
# Copyright (c) 2009 Luis Rocha
function Update-AssemblyInfoFiles([string] $version)
{
    $assemblyVersionPattern = 'AssemblyVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
    $fileVersionPattern = 'AssemblyFileVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
    $assemblyVersion = 'AssemblyVersion("' + $version + '")';
    $fileVersion = 'AssemblyFileVersion("' + $version + '")';
    
    Get-ChildItem -r -Include AssemblyInfo.cs, AssemblyInfo.vb | ForEach-Object {
        $filename = $_.Directory.ToString() + '\' + $_.Name
        $filename + ' -> ' + $version
        
        # If you are using a source control that requires to check-out files before 
        # modifying them, make sure to check-out the file here.
        # For example, TFS will require the following command:
        # tf checkout $filename
    
        (Get-Content $filename) | ForEach-Object {
            % {$_ -replace $assemblyVersionPattern, $assemblyVersion } |
            % {$_ -replace $fileVersionPattern, $fileVersion }
        } | Set-Content $filename
    }
}
