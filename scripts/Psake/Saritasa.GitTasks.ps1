<#PSScriptInfo

.VERSION 1.1.0

.GUID a8bc41d0-c2bd-459a-9e39-544b6f70724f

.AUTHOR Sergey Kondratov

.COMPANYNAME Saritasa

.COPYRIGHT (c) 2016 Saritasa. All rights reserved.

.TAGS Git GitFlow

.LICENSEURI https://raw.githubusercontent.com/Saritasa/PSGallery/master/LICENSE

.PROJECTURI https://github.com/Saritasa/PSGallery

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES

.SYNOPSIS
Contains Psake tasks for Git repository maintenance.

.DESCRIPTION
Contains following commands:
gitflow-* commands -- show status of gitflow branches with statistic and useful info.

#>

Import-Module Saritasa.Git

Task gitflow-hotfixes-releases -description 'Display remote release/* and hotfix/* branches.' `
{
    Write-Information 'This is a list of remote release branches. If release is done, need to remove the branch.'
    Get-GitFlowStatus -BranchType Release | Sort-Object Merged, Name | Format-Table
    Write-Information 'This is a list of remote hotfix branches. Usually we don''t push hotfix branches, because they are short living. Need to remove them.' 
    Get-GitFlowStatus -BranchType Hotfix | Sort-Object Merged, Name | Format-Table
}

Task gitflow-old-features -description 'Display Remote feature/* branches older than 2 weeks.' `
{
    Write-Information 'This is a list of old feature branches. Need to clarify their statuses.'
    Get-GitFlowStatus -BranchType Feature -OlderThanDays 14 | Sort-Object Merged, Name | Format-Table
}

Task gitflow-features -description 'Display list of all remote feature/* branches.' `
{
    Write-Information 'This is a list of remote feature branches. If branch is merged, need to remove it.'
    Get-GitFlowStatus -BranchType Feature | Sort-Object Merged, Name | Format-Table
}

Task gitflow-status -depends gitflow-features, gitflow-old-features, gitflow-hotfixes-releases -description '* Display information about GitFlow issues.'

Task delete-merged-branches -description 'Delete merged remote-tracking branches.' `
{
    Get-GitFlowStatus -BranchType Feature | Where-Object { $_.Merged -eq $true } | ForEach-Object { DeleteRemoteBranch($_.Name) }
    Get-GitFlowStatus -BranchType Release | Where-Object { $_.Merged -eq $true } | ForEach-Object { DeleteRemoteBranch($_.Name) }
    Get-GitFlowStatus -BranchType Hotfix | Where-Object { $_.Merged -eq $true } | ForEach-Object { DeleteRemoteBranch($_.Name) }
}

function DeleteRemoteBranch([string] $BranchName)
{
    Exec { git.exe branch -r -d $BranchName }
}
