Set-StrictMode -Version Latest

<#
.SYNOPSIS
Removes all empty directories under the given path.

.NOTES
Author: Daniel Schroeder
http://blog.danskingdom.com/powershell-functions-to-delete-old-files-and-empty-directories/

.EXAMPLE
Remove-EmptyDirectories -Path "C:\SomePath\Temp" -DeletePathIfEmpty
Delete all empty directories in the Temp folder, as well as the Temp folder itself if it is empty.

.EXAMPLE
-Remove-EmptyDirectories -Path "C:\SomePath\WithEmpty\Directories" -OnlyDeleteDirectoriesCreatedBeforeDate ([DateTime]::Parse("Jan 1, 2014 15:00:00"))
Delete all empty directories created after Jan 1, 2014 3PM.

.EXAMPLE
Remove-EmptyDirectories C:\SomePath\WithEmpty\Directories -OnlyDeleteDirectoriesCreatedBeforeDate [DateTime]::Today.AddDays(-1)
Delete all empty directories created before yesterday.
#>
function Remove-EmptyDirectories
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "",
                                                        Scope="Function", Target="*")]

    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        # Path to folder to scan.
        [parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_})]
        [string] $Path,
        # If set, the root folder (specified in Path variable) will also be removed if it complies the provided filters.
        [switch] $DeletePathIfEmpty,
        # If specified, only directories created before the given date will be removed.
        [DateTime] $OnlyDeleteDirectoriesCreatedBeforeDate = [DateTime]::MaxValue,
        # If specified, only directories last time modified before the given date will be removed.
        [DateTime] $OnlyDeleteDirectoriesNotModifiedAfterDate = [DateTime]::MaxValue
    )

    Get-ChildItem -Path $Path -Recurse -Force -Directory |
        Where-Object { $null -eq (Get-ChildItem -Path $_.FullName -Recurse -Force -File) } |
        Where-Object { $_.CreationTime -lt $OnlyDeleteDirectoriesCreatedBeforeDate -and $_.LastWriteTime -lt $OnlyDeleteDirectoriesNotModifiedAfterDate } |
        ForEach-Object `
        {
            Write-Verbose $_.FullName
            Remove-Item -Path $_.FullName -Force
        }

    if ($DeletePathIfEmpty)
    {
        $isFolder = (Test-Path -Path $Path -PathType Container)
        $isEmpty = $null -eq (Get-ChildItem -Path $Path -Force)
        $passesTimeRestrictions = ((Get-Item $Path).CreationTime -lt $OnlyDeleteDirectoriesCreatedBeforeDate) -and ((Get-Item $Path).LastWriteTime -lt $OnlyDeleteDirectoriesNotModifiedAfterDate)
        if ($isFolder -and $isEmpty -and $passesTimeRestrictions)
        {
            Write-Verbose $Path
            Remove-Item -Path $Path -Force
        }
    }
}

<#
.SYNOPSIS
Removes all files in the given Path that were created before the given date, as well as any empty directories that may be left behind.

.NOTES
Author: Daniel Schroeder
http://blog.danskingdom.com/powershell-functions-to-delete-old-files-and-empty-directories/

.EXAMPLE
Remove-FilesCreatedBeforeDate -Path "C:\Some\Directory" -DateTime ((Get-Date).AddDays(-2)) -DeletePathIfEmpty
Delete all files created more than 2 days ago.

.EXAMPLE
Remove-FilesCreatedBeforeDate -Path "C:\Another\Directory\SomeFile.txt" -DateTime ((Get-Date).AddMinutes(-30))
Delete a single file if it is more than 30 minutes old.

.EXAMPLE
Remove-FilesCreatedBeforeDate -Path "C:\SomePath\Temp" -DateTime (Get-Date) -DeletePathIfEmpty -WhatIf
See what files and directories would be deleted if we ran the command.
#>
function Remove-FilesCreatedBeforeDate
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_})]
        [string] $Path,
        [parameter(Mandatory = $true)]
        [DateTime] $DateTime,
        [switch] $DeletePathIfEmpty
    )
    Get-ChildItem -Path $Path -Recurse -Force -File |
        Where-Object { $_.CreationTime -lt $DateTime } |
		ForEach-Object `
        {
            Write-Verbose $_.FullName
            Remove-Item -Path $_.FullName -Force
        }
    Remove-EmptyDirectories -Path $Path -DeletePathIfEmpty:$DeletePathIfEmpty -OnlyDeleteDirectoriesCreatedBeforeDate $DateTime
}

<#
.SYNOPSIS
Removes all files in the given Path that have not been modified after the given date, as well as any empty directories that may be left behind.

.NOTES
Author: Daniel Schroeder
http://blog.danskingdom.com/powershell-functions-to-delete-old-files-and-empty-directories/

.EXAMPLE
Remove-FilesNotModifiedAfterDate -Path "C:\Another\Directory" -DateTime ((Get-Date).AddHours(-8))
Delete all files that have not been updated in 8 hours.
#>
function Remove-FilesNotModifiedAfterDate
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_})]
        [string] $Path,
        [parameter(Mandatory = $true)]
        [DateTime] $DateTime,
        [switch] $DeletePathIfEmpty
    )
    Get-ChildItem -Path $Path -Recurse -Force -File |
        Where-Object { $_.LastWriteTime -lt $DateTime } |
        ForEach-Object `
        {
            Write-Verbose $_.FullName
            Remove-Item -Path $_.FullName -Force
        }
    Remove-EmptyDirectories -Path $Path -DeletePathIfEmpty:$DeletePathIfEmpty -OnlyDeleteDirectoriesNotModifiedAfterDate $DateTime
}
