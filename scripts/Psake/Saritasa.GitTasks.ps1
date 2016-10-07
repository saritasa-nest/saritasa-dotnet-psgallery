#Requires -Modules psake

<#PSScriptInfo

.VERSION 1.0.0

.GUID a8bc41d0-c2bd-459a-9e39-544b6f70724f

.AUTHOR Sergey Kondratov

.COMPANYNAME Saritasa

.COPYRIGHT (c) 2016 Saritasa. All rights reserved.

.TAGS Psake

.LICENSEURI https://raw.githubusercontent.com/Saritasa/PSGallery/master/LICENSE

.PROJECTURI https://github.com/Saritasa/PSGallery

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES

.SYNOPSIS
Contains Psake tasks for git repository maintenance

.DESCRIPTION

#>

$root = $PSScriptRoot
$modules = "$root\Modules"

Import-Module "$modules\Saritasa.Git\Saritasa.Git.GitFlowStatus.psd1"

Task gitflow-hotfixes-releases -description 'Display remote release/* and hotfix/* branches.' `
{
    Get-GitFlowStatus -BranchType release
    Get-GitFlowStatus -BranchType hotfix
}

Task gitflow-old-features -description 'Display Remote feature/* branches older than 2 weeks.' `
{
    Get-GitFlowStatus -BranchType feature -OlderThanDays 14
}

Task gitflow-features -description 'Display list of all remote feature/* branches.' `
{
    Get-GitFlowStatus -BranchType feature
}