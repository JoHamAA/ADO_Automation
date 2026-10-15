$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"
$area = "PassengerDataHub"
$iteration = "PassengerDataHub"
$tags = "AI-StoryWriting; Migration to MongoDB; PNR GRAPH API"

$stories = @(
    @{
        Title = "PaxHub - Migration to MongoDB - PNR GRAPH API - Add Response Element isUATPPnr"
        Description = '<div><b>Given</b> the Customer PNR API currently exposes PNRUATPIndicator and PNR Graph API is being migrated to MongoDB<br><b>When</b> a client requests a PNR through PNR Graph API<br><b>Then</b> the response includes the boolean <b>isUATPPnr</b> with behavior compatible with Customer PNR API<br><b>And</b> existing clients can consume the new API without a UATP indicator regression</div><br><div><b>Context:</b> Implement isUATPPnr for PNR Graph API as part of the PNR MongoDB migration. Review the existing Customer PNR API logic. Set isUATPPnr to true when active remarks in <b>bkg</b> at reservation.remarks.remark.remarkLines.remarkLine.text or historical remarks in <b>bkg_hist</b> at history.historyTransaction.remarkHistory.ord_rmk_txt contain any of these strings: *TP103770, *TP10378, or *TP10379. Otherwise set the boolean to false. Use PROD PNR ADDGBK as a reference case. Update and deploy the GraphQL schema to Apollo, then load test and compare results with baseline statistics captured before implementation.</div>'
        AcceptanceCriteria = '<div><b>Return the UATP indicator from active and historical remarks</b><br><b>Given</b> a requested PNR has active or historical remarks in the MongoDB booking data<br><b>When</b> any active remark text or historical remark text contains *TP103770, *TP10378, or *TP10379<br><b>Then</b> PNR Graph API returns isUATPPnr as true<br><b>And</b> the response remains false when none of the configured strings are present.</div><br><div><b>Handle absent or malformed remark data safely</b><br><b>Given</b> either bkg or bkg_hist has no remarks, null remark text, malformed nested records, or an unavailable historical document<br><b>When</b> PNR Graph API resolves isUATPPnr<br><b>Then</b> the API returns a deterministic false value without failing the PNR response<br><b>And</b> diagnostics identify unexpected data shapes without exposing sensitive PNR data.</div><br><div><b>Publish the response field contract</b><br><b>Given</b> isUATPPnr is implemented in PNR Graph API<br><b>When</b> the GraphQL schema and API documentation are updated<br><b>Then</b> the schema defines isUATPPnr as a boolean with its active and historical remark evaluation behavior<br><b>And</b> the updated schema is deployed successfully to Apollo.</div><br><div><b>Demonstrate compatible performance and consumer behavior</b><br><b>Given</b> baseline PNR Graph API statistics are captured before the change<br><b>When</b> load testing is completed after implementation<br><b>Then</b> response time, error rate, and resource metrics are compared with the baseline and documented<br><b>And</b> representative PNRs, including ADDGBK where permitted, confirm no consumer-facing regression.</div>'
    }
    @{
        Title = "PaxHub - Migration to MongoDB - PNR GRAPH API - Add Response Element parentRecordLocator"
        Description = '<div><b>Given</b> Customer PNR API exposes PNRParentIdentifier and PNR Graph API is being migrated to MongoDB<br><b>When</b> a client requests a PNR through PNR Graph API<br><b>Then</b> the response includes <b>parentRecordLocator</b> with behavior compatible with Customer PNR API<br><b>And</b> clients can use the new API without losing the parent PNR reference</div><br><div><b>Context:</b> Implement parentRecordLocator for PNR Graph API as part of the PNR MongoDB migration. Review the existing Customer PNR API logic. Read the value from <b>bkg</b> at reservation.bookingDetails.divideSplitDetails.splitFromRecord[0].recordLocator. When splitFromRecord contains multiple objects, use the first object because it represents the original parent PNR after multiple divides. Update and deploy the GraphQL schema to Apollo, then load test and compare results with baseline statistics captured before implementation. Use STAGE PNR PTIGOH as a reference case.</div>'
        AcceptanceCriteria = '<div><b>Return the original parent record locator</b><br><b>Given</b> a requested PNR contains divideSplitDetails with one or more splitFromRecord entries<br><b>When</b> PNR Graph API resolves parentRecordLocator<br><b>Then</b> it returns reservation.bookingDetails.divideSplitDetails.splitFromRecord[0].recordLocator<br><b>And</b> when multiple splitFromRecord entries exist, it uses the first entry as the original parent PNR.</div><br><div><b>Handle PNRs without valid split history safely</b><br><b>Given</b> a PNR has no divideSplitDetails, an empty splitFromRecord array, a missing recordLocator, or an unexpected MongoDB document shape<br><b>When</b> PNR Graph API resolves parentRecordLocator<br><b>Then</b> it returns the documented null or absent response behavior without failing the overall PNR response<br><b>And</b> diagnostics identify unexpected data shapes without exposing sensitive PNR data.</div><br><div><b>Publish the parent locator field contract</b><br><b>Given</b> parentRecordLocator is implemented in PNR Graph API<br><b>When</b> the GraphQL schema and API documentation are updated<br><b>Then</b> the schema describes the field and states that the first splitFromRecord entry represents the original parent PNR after multiple divides<br><b>And</b> the updated schema is deployed successfully to Apollo.</div><br><div><b>Demonstrate compatible performance and consumer behavior</b><br><b>Given</b> baseline PNR Graph API statistics are captured before the change<br><b>When</b> load testing is completed after implementation<br><b>Then</b> response time, error rate, and resource metrics are compared with the baseline and documented<br><b>And</b> representative PNRs, including PTIGOH in STAGE, confirm no consumer-facing regression.</div>'
    }
)

function Get-ParentId {
    param($WorkItem)

    $parentRelation = @($WorkItem.relations | Where-Object { $_.rel -eq "System.LinkTypes.Hierarchy-Reverse" }) | Select-Object -First 1
    if (-not $parentRelation) { return $null }
    return [int]($parentRelation.url.Split('/')[-1])
}

Write-Host "PARENT none"

$rankWiql = "SELECT [System.Id], [Microsoft.VSTS.Common.StackRank] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.IterationPath] UNDER '$iteration' ORDER BY [Microsoft.VSTS.Common.StackRank] ASC"
$rankItems = @(az boards query --organization $org --project $project --wiql $rankWiql --output json | ConvertFrom-Json)
$priorMinRank = $null
$rankValues = @($rankItems | ForEach-Object { $_.fields.'Microsoft.VSTS.Common.StackRank' } | Where-Object { $null -ne $_ })
if ($rankValues.Count -gt 0) {
    $priorMinRank = [double]$rankValues[0]
}

if ($null -eq $priorMinRank) {
    $baseRank = -1000000
    Write-Host "RANK priorMin=unavailable fallback=$baseRank"
} else {
    $baseRank = $priorMinRank - 1000
    Write-Host "RANK priorMin=$priorMinRank base=$baseRank"
}

$createdIds = @()
for ($index = 0; $index -lt $stories.Count; $index++) {
    $story = $stories[$index]
    $escapedTitle = $story.Title.Replace("'", "''")
    $duplicateWiql = "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.Title] = '$escapedTitle'"
    $duplicates = @(az boards query --organization $org --project $project --wiql $duplicateWiql --output json | ConvertFrom-Json)
    if ($duplicates.Count -gt 0) {
        $duplicateId = $duplicates[0].id
        throw "DUPLICATE duplicate_exists title=$($story.Title) id=$duplicateId url=$org/$project/_workitems/edit/$duplicateId"
    }
    Write-Host "DUPLICATE none title=$($story.Title)"

    $stackRank = $baseRank - ($index * 100)
    $created = az boards work-item create `
        --organization $org `
        --project $project `
        --type "User Story" `
        --title $story.Title `
        --area $area `
        --iteration $iteration `
        --fields "System.Description=$($story.Description)" `
                 "Microsoft.VSTS.Common.AcceptanceCriteria=$($story.AcceptanceCriteria)" `
                 "Microsoft.VSTS.Scheduling.StoryPoints=0" `
                 "Microsoft.VSTS.Common.Priority=2" `
                 "AAIT.Ready=Yes" `
                 "AAIT.WorkType=4. Software / UX" `
                 "System.State=Backlog" `
                 "System.Tags=$tags" `
                 "Microsoft.VSTS.Common.StackRank=$stackRank" `
        --output json | ConvertFrom-Json

    if (-not $created.id) { throw "CREATE failed to return a work item ID for $($story.Title)." }
    $createdIds += $created.id
    Write-Host "CREATE id=$($created.id) rank=$stackRank title=$($story.Title)"
}

foreach ($createdId in $createdIds) {
    $verified = az boards work-item show --id $createdId --organization $org --expand all --output json | ConvertFrom-Json
    $expected = @($stories | Where-Object { $_.Title -eq $verified.fields.'System.Title' }) | Select-Object -First 1
    $verifiedRank = [double]$verified.fields.'Microsoft.VSTS.Common.StackRank'
    $checks = @(
        ($verified.fields.'System.WorkItemType' -eq "User Story"),
        ($verified.fields.'System.State' -eq "Backlog"),
        ($verified.fields.'System.AreaPath' -eq $area),
        ($verified.fields.'System.IterationPath' -eq $iteration),
        ($verified.fields.'System.Tags' -like "*AI-StoryWriting*"),
        ($null -eq (Get-ParentId -WorkItem $verified)),
        ($verified.fields.'System.Description' -eq $expected.Description),
        ($verified.fields.'Microsoft.VSTS.Common.AcceptanceCriteria' -eq $expected.AcceptanceCriteria)
    )
    if ($null -ne $priorMinRank) { $checks += ($verifiedRank -lt $priorMinRank) }
    if ($checks -contains $false) { throw "VERIFY failed for work item $createdId." }

    Write-Host "LINK none child=$createdId"
    Write-Host "VERIFY id=$createdId url=$org/$project/_workitems/edit/$createdId type=$($verified.fields.'System.WorkItemType') state=$($verified.fields.'System.State') area=$($verified.fields.'System.AreaPath') iteration=$($verified.fields.'System.IterationPath') tags=$($verified.fields.'System.Tags') stackRank=$verifiedRank parent=none"
    Write-Host "VERIFY_DESCRIPTION $($verified.fields.'System.Description')"
    Write-Host "VERIFY_ACCEPTANCE_CRITERIA $($verified.fields.'Microsoft.VSTS.Common.AcceptanceCriteria')"
}