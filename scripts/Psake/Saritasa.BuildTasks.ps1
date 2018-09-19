
<#PSScriptInfo

.VERSION 1.0.1

.GUID b9173d19-1d34-4508-95cb-77979efaac87

.AUTHOR Anton Zimin

.COMPANYNAME Saritasa

.COPYRIGHT (c) 2018 Saritasa. All rights reserved.

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
}


function GetMasterTagArray()
{
    $result = $null
    $masterTag = git describe --tags --exact-match master

    if (!$LASTEXITCODE)
    {
        $values = $masterTag -split '\.'

        if ($values.Length -eq 3)
        {
            $result = $values
        }
    }

    $result
}

Task get-version `
    -description 'Fills version properties by info from Git. Works faster than GitVersion.' `
{
    $defaultVersion = '0.0.0'
    $description = $null

    $result = @{}
    $suffix = $null

    $branch = Exec { git rev-parse --abbrev-ref HEAD }

    if ($branch -eq 'master')
    {
        $tag = Exec { git describe --tags --exact-match HEAD }
        $values = $tag -split '\.'

        if ($values.Length -ne 3)
        {
            throw 'Wrong tag format. Expected SemVer: x.x.x'
        }

        $description = "Master branch"
        $suffix = ''
        $result.MajorMinorPatch = $tag
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

        elseif ($branch -match 'hotfix/(.*)')
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
        $values = GetMasterTagArray

        if ($values)
        {
            $version = $values[0] + '.' + ([int]$values[1] + 1) + '.0'
        }
        else
        {
            $version = $defaultVersion
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

    Write-Information "$description, $MajorMinorPatch, $InformationalVersion"
}
