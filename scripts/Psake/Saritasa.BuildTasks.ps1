
<#PSScriptInfo

.VERSION 1.2.4

.GUID b9173d19-1d34-4508-95cb-77979efaac87

.AUTHOR Anton Zimin

.COMPANYNAME Saritasa

.COPYRIGHT (c) 2018-2019 Saritasa. All rights reserved.

.TAGS Git GitVersion

.LICENSEURI https://raw.githubusercontent.com/Saritasa/PSGallery/master/LICENSE

.PROJECTURI https://github.com/Saritasa/PSGallery

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES

.SYNOPSIS
Contains Psake tasks for .NET projects build.

.DESCRIPTION

#>

Properties `
{
    $InformationalVersion = $null
    $MajorMinorPatch = $null
    $AssemblySemVer = $null
}

Function ExecuteCommand ([string] $CommandPath, [string] $CommandArguments)
{
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $CommandPath
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $CommandArguments
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    [pscustomobject] `
    @{
        StandardOutput = $p.StandardOutput.ReadToEnd().Trim()
        StandardError = $p.StandardError.ReadToEnd().Trim()
        ExitCode = $p.ExitCode
        Success = $p.ExitCode -eq 0
    }
    $p.WaitForExit()
}

function GetMasterTagArray()
{
    $result = $null
    $gitResult = ExecuteCommand 'git' 'describe --tags --exact-match origin/master'

    if ($gitResult.Success)
    {
        $masterTag = $gitResult.StandardOutput
        $values = $masterTag -split '\.'

        if ($values.Length -eq 3)
        {
            $result = $values
        }
    }

    $result
}

# Returns SemVer tag or $null.
function GetSemVerTag()
{
    $gitResult = ExecuteCommand 'git' 'describe --tags --exact-match HEAD'
    $tag = $gitResult.StandardOutput
    $semVerTag = $null

    if ($gitResult.Success -and $tag)
    {
        if ($tag -match '\d+\.\d+\.\d+')
        {
            $semVerTag = $tag
        }
        else
        {
            Write-Information "Found tag $tag with wrong format, skipped. Expected SemVer: x.x.x"
        }
    }

    $semVerTag
}

Task get-version `
    -description 'Fills version properties by info from Git. Works faster than GitVersion.' `
{
    $defaultVersion = '0.0.0'
    $description = $null

    $result = @{}
    $suffix = $null

    $branch = Exec { git rev-parse --abbrev-ref HEAD }
    $semVerTag = GetSemVerTag

    if ($branch -eq 'master')
    {
        if (!$semVerTag)
        {
            throw 'Production releases without tag are not allowed.'
        }

        $description = "Master branch"
        $suffix = ''
        $result.MajorMinorPatch = $semVerTag
    }
    elseif ($branch -like 'release/*')
    {
        if ($branch -match 'release/(\d+\.\d+\.\d+)')
        {
            $version = $Matches[1]
        }
        else
        {
            throw 'Wrong release name. Expected SemVer: release/x.x.x'
        }

        $description = "Release branch"
        $suffix = '-beta'
        $result.MajorMinorPatch = $version
    }
    elseif ($branch -like 'hotfix/*')
    {
        $values = GetMasterTagArray

        if ($values)
        {
            $version = $values[0] + '.' + $values[1] + '.' + ([int]$values[2] + 1)
        }
        else
        {
            $version = $defaultVersion
        }

        if ($branch -match 'hotfix/(.*)')
        {
            $description = 'Hotfix branch'
            $suffix = '-' + $Matches[1]
        }
        else
        {
            $description = 'Unknown branch'
            $suffix = '-unknown'
        }

        $result.MajorMinorPatch = $version
    }
    elseif ($branch -eq 'HEAD')
    {
        throw 'Detached HEAD detected. Enable "Check out to specific local branch" behavior in Jenkins.'
    }
    else
    {
        if ($semVerTag) # Tag is assigned to commit in develop branch.
        {
            $version = $semVerTag
        }
        else # Calculate version by master branch.
        {
            $values = GetMasterTagArray

            if ($values)
            {
                $version = $values[0] + '.' + ([int]$values[1] + 1) + '.0'
            }
            else
            {
                $version = $defaultVersion
            }
        }

        if ($branch -eq 'develop')
        {
            $description = 'Develop branch'
            $suffix = '-develop'
        }
        elseif ($branch -match 'feature/(.*)')
        {
            $description = 'Feature branch'
            $suffix = '-' + $Matches[1]
        }
        else
        {
            $description = 'Unknown branch'
            $suffix = '-unknown'
        }

        $result.MajorMinorPatch = $version
    }

    $changeset = Exec { git rev-parse HEAD }
    $result.InformationalVersion = ($result.MajorMinorPatch + $suffix +
        "+$branch.$changeset") -replace '/', '-'

    if (!$InformationalVersion)
    {
        # 1.2.3+master.dc6ebc32aa8ecf20529a677d896a8263df4900ee
        # 1.3.0-beta+release/1.3.0.56793f7f6259dd4042d57e9d206cb9b1d8434508
        Expand-PsakeConfiguration @{ InformationalVersion = $result.InformationalVersion }
    }

    if (!$MajorMinorPatch)
    {
        # 1.2.3
        # 1.3.0
        Expand-PsakeConfiguration @{ MajorMinorPatch = $result.MajorMinorPatch }
    }

    if (!$AssemblySemVer)
    {
        # 1.2.3.0
        # 1.3.0.0
        Expand-PsakeConfiguration @{ AssemblySemVer = ($result.MajorMinorPatch + '.0') }
    }

    Write-Information "$description, $MajorMinorPatch, $InformationalVersion"
}
