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
