

[string]
$UpsourceUrl = ''
[pscredential]
$UpsourceCredentials


function Initialize-Upsource {

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $UpsourceUrl,
        [Parameter(Mandatory = $true)]
        [pscredential] $Credential
    )

    $script:UpsourceUrl = $UpsourceUrl
    $script:UpsourceCredentials = $Credential

    Write-Debug $script:UpsourceUrl
    Write-Debug $script:UpsourceCredentials
}


<#
    Encoding string to base64
 #>
function EncodeBase64 {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $textBytes = [System.Text.Encoding]::UTF8.GetBytes($value)

    $encodedText = [Convert]::ToBase64String($textBytes)


    return $encodedText
}

<#
    Credentials encoding helper
 #>
function CredentialsEncoded {

    $value = $UpsourceCredentials.UserName + ":" + $UpsourceCredentials.GetNetworkCredential().Password
    return EncodeBase64 -Value $value
}

<#
    Web request helper
 #>
function Invoke-Request {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [string]$Body
    )

    $credentialsEncoded = CredentialsEncoded

    $jsonBody = ConvertTo-Json -InputObject $Body | Out-File "request-body.json"

    Invoke-RestMethod  -ContentType 'application/json' -Headers @{'Authorization' = "Basic $credentialsEncoded"} `
        -Body $Body `
        -Method Post `
        -Uri $Url `

    return
}

<#
    Get all revisions for project
 #>
function Get-RevisionsList {

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$Project,

        [int]$Limit = [int]::MaxValue
    )

    $revisionListDto = @{
        projectId    = $Project
        limit        = $Limit
        requestGraph = $false
    } | ConvertTo-Json

    $url = "$UpsourceUrl/~rpc/getRevisionsList"

    $revisionList = Invoke-Request -Url $url -Body $revisionListDto

    $revisionIds = @()

    $revisionList.result.revision | ForEach-Object { 

        if ($_ -ne $null) {

            $revisionObject = @{  
                RevisionId    = $_.revisionId 
                Date          = $_.revisionDate
                CommitMessage = $_.revisionCommitMessage
                Author        = $_.authorId
            }

            $revisionIds += $revisionObject
        }
    }

    return $revisionIds
}

function Get-RevisionListFiltered {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$ProjectId,

        [int]$Limit = 30, 

        [string]$Query
    )

    $requestDto = @{
        projectId    = $ProjectId
        limit        = $Limit
        query        = $Query
        requestGraph = $false
    } | ConvertTo-Json

    $url = "$UpsourceUrl/~rpc/getRevisionsListFiltered"

    $revisionIds = @()

    $result = Invoke-Request -Url $url -Body $requestDto

    $result.result.revision | ForEach-Object { $revisionIds += $_.revisionId }

    $revisionIds

    return
}

function Get-RevisionsInReview {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$ProjectId,

        [Parameter(Mandatory = $true)]
        [string]$ReviewId
    )

    $params = @{
        projectId = $ProjectId
        reviewId  = $ReviewId
    } | ConvertTo-Json

    $url = "$UpsourceUrl/~rpc/getRevisionsInReview"

    $revisionIds = @()

    $result = Invoke-Request -Url $url -Body $params

    ([string]$result.result.newRevisions.revisions).Split(' ') | ForEach-Object { $revisionIds += $_ }

    $revisionIds

    return 
}

function Get-ReviewsList {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [int]
        $Limit,

        [string]
        $Query,

        [string]
        $ProjectId
    )

    $url = "$UpsourceUrl/~rpc/getReviews"

    $reviewsRequestDto = @{
        limit     = $Limit
        query     = $Query
        projectId = $ProjectId
    } | ConvertTo-Json

    $result = Invoke-Request -Url $url -Body $reviewsRequestDto

    $reviewIds = @()

    $result.result.reviews.reviewId.reviewId | ForEach-Object { $reviewIds += $_ }

    $reviewIds

    return
}

function Get-RevisionWithoutReview {

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$Project,
        [string]$Branch = 'develop',
        [int]$DaysLimit = 30
    )

    [datetime]$now = [datetime]::Now
    $from = $now.Date.AddDays(-$DaysLimit)

    $endDateString = $now.ToString("yyyy-MMM-dd")
    $startDateString = $from.Date.ToString("yyyy-MMM-dd")

    [string]$dateQuery = "created: $startDateString .. $endDateString"

    $branchQuery = "branch:$Branch and date:$startDateString .. $endDateString"

    $allRevisions = Get-RevisionListFiltered -ProjectId $Project -Limit 10000 -Query $branchQuery

    $allReviews = Get-ReviewsList -ProjectId $Project -Limit 100 -Query $dateQuery

    $allRevisionsCount = $allRevisions.Count
    $allReviewsCount = $allReviews.Count

    Write-Output "Revisions: $allRevisionsCount"

    Write-Output "Reviews: $allReviewsCount"
}

Export-ModuleMember -Function "Get-*"
Export-ModuleMember -Function "Initialize-Upsource"