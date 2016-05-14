function Invoke-NugetRestore
{
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = 'Path to solution. All NuGet packages from included projects will be restored.')]
        [string] $SolutionPath
    )

    $nugetExePath = "$PSScriptRoot\nuget.exe"
    
    if (!(Test-Path $nugetExePath))
    {
        Invoke-WebRequest 'http://nuget.org/nuget.exe' -OutFile $nugetExePath
    }
    
    &$nugetExePath 'restore' $SolutionPath
    if ($LASTEXITCODE)
    {
        throw 'Nuget restore failed.'
    }
}

function Invoke-SolutionBuild
{
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = 'Path to solution.')]
        [string] $SolutionPath,
        [Parameter(HelpMessage = 'Build configuration (Release, Debug, etc.)')]
        [string] $Configuration
    )

    Invoke-ProjectBuild $SolutionPath $Configuration
}

function Invoke-ProjectBuild
{
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = 'Path to project.')]
        [string] $ProjectPath,
        [Parameter(HelpMessage = 'Build configuration (Release, Debug, etc.)')]
        [string] $Configuration,
        [string] $Target = 'Build',
        [string[]] $BuildParams
    )

    msbuild.exe $ProjectPath '/m' "/t:$Target" "/p:Configuration=$Configuration" '/verbosity:normal' $BuildParams
    if ($LASTEXITCODE)
    {
        throw 'Build failed.'
    }
}

<#
.SYNOPSIS
Update version numbers of AssemblyInfo.cs and AssemblyInfo.vb.

.NOTES
Based on SetVersion script.
http://www.luisrocha.net/2009/11/setting-assembly-version-with-windows.html
Copyright (c) 2009 Luis Rocha
#>
function Update-AssemblyInfoFiles
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = 'Version string in major.minor.build.revision format.')]
        [string] $Version
    )

    $assemblyVersionPattern = 'AssemblyVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
    $fileVersionPattern = 'AssemblyFileVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
    $assemblyVersion = 'AssemblyVersion("' + $Version + '")';
    $fileVersion = 'AssemblyFileVersion("' + $Version + '")';
    
    Get-ChildItem -r -Include AssemblyInfo.cs, AssemblyInfo.vb | ForEach-Object {
        $filename = $_.Directory.ToString() + '\' + $_.Name
        $filename + ' -> ' + $Version
        
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

function Copy-DotnetConfig
{
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = 'Path to App.config.template or Web.config.template file.')]
        [string] $TemplateFilename
    )

    $configFilename = $TemplateFilename -replace '\.template', ''
    if (!(Test-Path $configFilename))
    {
        Copy-Item $TemplateFilename $configFilename
    }
}
