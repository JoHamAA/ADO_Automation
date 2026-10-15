$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"
$parentId = 3171294

$stories = @(
    @{
        Title = "PaxHub - Migration to MongoDB - LMRI GraphQL API - Remove NONREV PNRs from Query Pull"
        Description = '<div><b>Given</b> Mobile clients must not receive NONREV PNRs from the LMRI GraphQL API<br><b>When</b> the LMRI MongoDB query retrieves PNR data for the Graph response<br><b>Then</b> NONREV PNRs are excluded from the query pull and are not returned to Mobile consumers<br><b>And</b> revenue PNR behavior and the existing LMRI response contract remain unchanged</div><br><div><b>Context:</b> Implement a temporary quick fix so the Mobile team can release its LMRI Graph integration. Remove NONREV PNRs from the MongoDB query pull before they are assembled into the LMRI Graph response. Define the approved NONREV identification and filtering logic, preserve ordinary revenue PNR processing, and validate the change against representative data without exposing or modifying PNR data.</div>'
        AcceptanceCriteria = '<div><b>Exclude NONREV PNRs from the LMRI query</b><br><b>Given</b> the MongoDB LMRI query encounters NONREV and revenue PNR records<br><b>When</b> the query and response assembly execute<br><b>Then</b> NONREV PNRs are filtered out before the LMRI Graph response is returned<br><b>And</b> eligible revenue PNRs continue through the existing response flow.</div><br><div><b>Handle missing or unexpected classification data safely</b><br><b>Given</b> a PNR has missing, malformed, or unexpected values used to classify NONREV status<br><b>When</b> the filtering logic evaluates the record<br><b>Then</b> the API follows documented safe behavior without returning an unintended NONREV PNR or destabilizing the query<br><b>And</b> actionable diagnostics do not expose sensitive PNR details.</div><br><div><b>Preserve the LMRI API contract for eligible PNRs</b><br><b>Given</b> a Mobile consumer requests LMRI Graph data for an eligible revenue PNR<br><b>When</b> the updated query executes<br><b>Then</b> existing fields, response shape, pagination or retrieval semantics, and downstream behavior remain compatible<br><b>And</b> the temporary filtering logic is documented for later replacement or removal.</div><br><div><b>Validate Mobile readiness and query performance</b><br><b>Given</b> the Mobile team needs the change to release its LMRI Graph integration<br><b>When</b> functional, regression, and performance validation is completed<br><b>Then</b> representative NONREV PNRs are absent and revenue PNRs remain available<br><b>And</b> query latency, error rate, result counts, and downstream impact are compared with the baseline.</div>'
    }
    @{
        Title = "PaxHub - Migration to MongoDB - LMRI GraphQL API - Expose Element segmentStatusCode in API Response"
        Description = '<div><b>Given</b> Mobile clients need to distinguish NONREV and revenue PNRs using LMRI Graph data<br><b>When</b> the LMRI MongoDB query and GraphQL response are updated<br><b>Then</b> the segment status code is returned as the new response element <b>segmentStatusCode</b><br><b>And</b> status code MM is available to support Mobile classification while existing eligible PNR behavior remains compatible</div><br><div><b>Context:</b> Re-add segment status code MM to the LMRI query pull and expose the resulting segment status code through the LMRI GraphQL API. Update the GraphQL schema and publish it to Apollo. Define the response mapping and behavior for missing or unexpected segment status values so Mobile can determine NONREV or revenue PNRs without relying on unavailable booking data.</div>'
        AcceptanceCriteria = '<div><b>Return segmentStatusCode for LMRI segments</b><br><b>Given</b> the LMRI query retrieves segments with approved status values, including MM<br><b>When</b> the LMRI GraphQL response is assembled<br><b>Then</b> each applicable segment exposes the new segmentStatusCode response element with the source status value<br><b>And</b> status code MM is no longer excluded solely by the query filter.</div><br><div><b>Handle absent and unexpected segment status values safely</b><br><b>Given</b> a segment has a missing, null, malformed, or unrecognized status code<br><b>When</b> segmentStatusCode is resolved<br><b>Then</b> the API applies documented null or error behavior without failing the complete LMRI response<br><b>And</b> diagnostics do not expose sensitive PNR or Mobile customer data.</div><br><div><b>Update and publish the GraphQL contract</b><br><b>Given</b> segmentStatusCode is a new consumer-facing response element<br><b>When</b> implementation is completed<br><b>Then</b> the GraphQL schema, documentation, and representative examples define the element and its status-code semantics<br><b>And</b> the updated schema is successfully published to Apollo and is available to consumers.</div><br><div><b>Validate Mobile compatibility and performance</b><br><b>Given</b> Mobile will use segmentStatusCode to determine NONREV or revenue PNR behavior<br><b>When</b> functional, schema, regression, and performance tests are completed<br><b>Then</b> MM and representative revenue status codes are returned correctly without breaking existing consumers<br><b>And</b> response latency, error rate, and query result behavior are compared with the baseline.</div>'
    }
)

function Get-ParentId {
    param($WorkItem)
    $relation = @($WorkItem.relations | Where-Object { $_.rel -eq "System.LinkTypes.Hierarchy-Reverse" }) | Select-Object -First 1
    if (-not $relation) { return $null }
    return [int]($relation.url.Split('/')[-1])
}

$parent = az boards work-item show --id $parentId --organization $org --expand all --output json | ConvertFrom-Json
if ($parent.fields.'System.TeamProject' -ne $project) { throw "PARENT $parentId is not in $project." }
if ($parent.fields.'System.WorkItemType' -ne "Feature") { throw "PARENT $parentId is not a Feature." }
$area = $parent.fields.'System.AreaPath'
$iteration = $parent.fields.'System.IterationPath'
$parentTags = @($parent.fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$tags = @($parentTags + "AI-StoryWriting" | Sort-Object -Unique) -join "; "
Write-Host "PARENT id=$parentId type=Feature area=$area iteration=$iteration tags=$tags"

foreach ($story in $stories) {
    $escapedTitle = $story.Title.Replace("'", "''")
    $duplicateWiql = "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.Title] = '$escapedTitle'"
    $duplicates = @(az boards query --organization $org --project $project --wiql $duplicateWiql --output json | ConvertFrom-Json)
    if ($duplicates.Count -gt 0) { throw "DUPLICATE duplicate_exists title=$($story.Title) id=$($duplicates[0].id) url=$org/$project/_workitems/edit/$($duplicates[0].id)" }
    Write-Host "DUPLICATE none title=$($story.Title)"
}

$rankWiql = "SELECT [System.Id], [Microsoft.VSTS.Common.StackRank] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.IterationPath] UNDER '$iteration' ORDER BY [Microsoft.VSTS.Common.StackRank] ASC"
$rankItems = @(az boards query --organization $org --project $project --wiql $rankWiql --output json | ConvertFrom-Json)
$rankValues = @($rankItems | ForEach-Object { $_.fields.'Microsoft.VSTS.Common.StackRank' } | Where-Object { $null -ne $_ })
if ($rankValues.Count -gt 0) { $priorMinRank = [double]$rankValues[0]; $baseRank = $priorMinRank - 1000; Write-Host "RANK priorMin=$priorMinRank base=$baseRank" }
else { $priorMinRank = $null; $baseRank = -1000000; Write-Host "RANK priorMin=unavailable fallback=$baseRank" }

$createdIds = @()
for ($index = 0; $index -lt $stories.Count; $index++) {
    $story = $stories[$index]
    $stackRank = $baseRank - ($index * 100)
    $created = az boards work-item create --organization $org --project $project --type "User Story" --title $story.Title --area $area --iteration $iteration --fields "System.Description=$($story.Description)" "Microsoft.VSTS.Common.AcceptanceCriteria=$($story.AcceptanceCriteria)" "Microsoft.VSTS.Scheduling.StoryPoints=0" "Microsoft.VSTS.Common.Priority=2" "AAIT.Ready=Yes" "AAIT.WorkType=4. Software / UX" "System.State=Backlog" "System.Tags=$tags" "Microsoft.VSTS.Common.StackRank=$stackRank" --output json | ConvertFrom-Json
    if (-not $created.id) { throw "CREATE failed for $($story.Title)." }
    $createdIds += $created.id
    Write-Host "CREATE id=$($created.id) rank=$stackRank title=$($story.Title)"
    az boards work-item relation add --id $created.id --organization $org --relation-type parent --target-id $parentId --output json | Out-Null
    Write-Host "LINK child=$($created.id) parent=$parentId"
}

foreach ($createdId in $createdIds) {
    $verified = az boards work-item show --id $createdId --organization $org --expand all --output json | ConvertFrom-Json
    $expected = @($stories | Where-Object { $_.Title -eq $verified.fields.'System.Title' }) | Select-Object -First 1
    $checks = @($verified.id -eq $createdId, $null -ne $expected, $verified.fields.'System.WorkItemType' -eq "User Story", $verified.fields.'System.State' -eq "Backlog", $verified.fields.'System.AreaPath' -eq $area, $verified.fields.'System.IterationPath' -eq $iteration, $verified.fields.'System.Tags' -like "*AI-StoryWriting*", (Get-ParentId -WorkItem $verified) -eq $parentId, $verified.fields.'System.Description' -eq $expected.Description, $verified.fields.'Microsoft.VSTS.Common.AcceptanceCriteria' -eq $expected.AcceptanceCriteria)
    if ($null -ne $priorMinRank) { $checks += ([double]$verified.fields.'Microsoft.VSTS.Common.StackRank' -lt $priorMinRank) }
    if ($checks -contains $false) { throw "VERIFY failed for work item $createdId." }
    Write-Host "VERIFY id=$createdId url=$org/$project/_workitems/edit/$createdId type=$($verified.fields.'System.WorkItemType') state=$($verified.fields.'System.State') area=$($verified.fields.'System.AreaPath') iteration=$($verified.fields.'System.IterationPath') tags=$($verified.fields.'System.Tags') stackRank=$($verified.fields.'Microsoft.VSTS.Common.StackRank') parent=$parentId description=true acceptanceCriteria=true"
}