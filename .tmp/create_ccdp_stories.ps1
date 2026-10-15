$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "DataEngineering"
$parentId = 3150151

$stories = @(
    @{ Suffix = "Enable Operational Data Sync to Customer Context"; Context = "Enable CCDP to ingest certified Stage Gold operational disruption data for customer context assembly. Source domains remain systems of record; CCDP owns correlation, projection, coverage, and serving. The initial Journey Inspirations consumer needs current operational disruption signals to suppress unsuitable communications, while the design must support future enterprise consumers and future near-real-time delivery."; Outcome = "certified operational disruption data is synchronized into the CCDP projection with traceable source ownership, freshness, and quality status"; Error = "the source product is delayed, unavailable, malformed, or does not meet its contract"; Documentation = "source-to-target mapping, data contract, ownership, freshness expectation, and operational runbook"; Measure = "load completeness, latency, error rate, and duplicate handling meet the agreed service objectives" },
    @{ Suffix = "Enable PNR Data Sync to Customer Context"; Context = "Enable CCDP to ingest certified Stage Gold reservation and PNR data needed to assemble journey context. CCDP must not consume operational or intermediate layers directly and must not become the system of record. The resulting projection supports active reservation, future travel, journey status, itinerary, and related customer-context signals."; Outcome = "PNR data is synchronized into the CCDP projection using approved customer and PNR correlation rules"; Error = "a PNR record is missing required identifiers, arrives out of order, is duplicated, or violates the certified data contract"; Documentation = "PNR source mapping, correlation keys, lifecycle rules, freshness expectation, and data-quality controls"; Measure = "synchronization preserves PNR lifecycle correctness, avoids duplicate context records, and meets agreed latency and reliability objectives" },
    @{ Suffix = "Enable Customer View Sync to Customer Context"; Context = "Enable CCDP to synchronize the certified Customer view required for customer identity and profile context. Customer domain remains the system of record. CCDP uses the view only to correlate and project customer context for Journey Inspirations and future enterprise consumers."; Outcome = "the certified Customer view is synchronized into CCDP with approved identity keys and a traceable projection state"; Error = "customer records have missing identifiers, conflicting attributes, schema changes, or delayed source delivery"; Documentation = "customer view mapping, approved identity and correlation keys, privacy handling, freshness expectation, and data-quality controls"; Measure = "synchronization maintains identity consistency, prevents unintended exposure, and meets agreed freshness and reliability objectives" },
    @{ Suffix = "Create Combined PNR, Flight Status, and AAdvantage Context View"; Context = "Create a reusable CCDP context view that joins certified PNR, flight-status, and AAdvantage information. The view provides a consolidated, governed projection for Journey Inspirations delivery decisions, including journey and disruption context, while keeping each source domain as the system of record."; Outcome = "a governed combined context view joins approved PNR, flight-status, and AAdvantage data using documented correlation rules"; Error = "records cannot be correlated, source data is late or incomplete, or one source emits an unexpected contract value"; Documentation = "view schema, join keys, field lineage, ownership boundaries, refresh behavior, and known null or ambiguity handling"; Measure = "the view returns consistent context at agreed scale, freshness, and query performance without duplicating or leaking customer data" },
    @{ Suffix = "Create Data API to Expose Combined Customer Context View"; Context = "Create the CCDP data API that exposes the combined customer-context view through a standardized contract. CCDP provides context only and does not create offers. The API is initially used by Journey Inspirations and must remain reusable by future customer-facing initiatives."; Outcome = "authorized consumers can retrieve standardized combined customer context by approved customer identifier"; Error = "a request has an invalid or unauthorized identifier, context is unavailable, or an upstream projection returns unexpected data"; Documentation = "API contract, schema, authentication and authorization requirements, response semantics, error model, and consumer integration guidance"; Measure = "the API meets agreed availability, response-time, security, observability, and consumer-compatibility objectives" }
)

function Get-WorkItemIdFromUrl {
    param([string]$Url)
    return [int]($Url.Split('/')[-1])
}

function Get-ParentId {
    param($WorkItem)
    $relation = @($WorkItem.relations | Where-Object { $_.rel -eq "System.LinkTypes.Hierarchy-Reverse" }) | Select-Object -First 1
    if (-not $relation) { return $null }
    return Get-WorkItemIdFromUrl -Url $relation.url
}

$parent = az boards work-item show --id $parentId --organization $org --expand all --output json | ConvertFrom-Json
if ($parent.fields.'System.TeamProject' -ne $project) { throw "PARENT $parentId is not in $project." }
if ($parent.fields.'System.WorkItemType' -ne "Feature") { throw "PARENT $parentId is not a Feature." }

$area = $parent.fields.'System.AreaPath'
$iteration = $parent.fields.'System.IterationPath'
$parentTags = @($parent.fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$tags = @($parentTags + "AI-StoryWriting" + "Customer Context DP" | Sort-Object -Unique) -join "; "
Write-Host "PARENT id=$parentId type=Feature area=$area iteration=$iteration tags=$tags"

foreach ($story in $stories) {
    $story.Title = "Journey Inspirations - Customer Context DP - $($story.Suffix)"
    $story.Description = "<div><b>Given</b> CCDP consumes only certified NorthStar Stage Gold data products and source domains remain systems of record<br><b>When</b> the team implements $($story.Suffix.ToLowerInvariant())<br><b>Then</b> $($story.Outcome)<br><b>And</b> the implementation supports Journey Inspirations without limiting future enterprise consumers</div><br><div><b>Context:</b> $($story.Context)</div>"
    $story.AcceptanceCriteria = "<div><b>Implement the approved customer-context capability</b><br><b>Given</b> certified source products and approved domain ownership are available<br><b>When</b> $($story.Suffix.ToLowerInvariant()) is implemented<br><b>Then</b> $($story.Outcome)<br><b>And</b> source domains remain authoritative for their underlying data.</div><br><div><b>Handle invalid, incomplete, and delayed source data</b><br><b>Given</b> $($story.Error)<br><b>When</b> processing or retrieval encounters the condition<br><b>Then</b> the capability applies documented validation, retry, quarantine, or safe response behavior without system instability<br><b>And</b> operational logs provide actionable diagnostics without exposing sensitive customer data.</div><br><div><b>Document the governed data contract</b><br><b>Given</b> the capability is ready for review<br><b>When</b> design and delivery artifacts are finalized<br><b>Then</b> $($story.Documentation) are documented and approved<br><b>And</b> consumer-facing semantics and change-management expectations are published.</div><br><div><b>Validate reliability, security, and consumer impact</b><br><b>Given</b> the capability is deployed to its target environment<br><b>When</b> functional, performance, and security validation is completed<br><b>Then</b> $($story.Measure)<br><b>And</b> Journey Inspirations integration and future-consumer impact are assessed before release.</div>"
}

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
if ($rankValues.Count -gt 0) {
    $priorMinRank = [double]$rankValues[0]
    $baseRank = $priorMinRank - 1000
    Write-Host "RANK priorMin=$priorMinRank base=$baseRank"
} else {
    $priorMinRank = $null
    $baseRank = -1000000
    Write-Host "RANK priorMin=unavailable fallback=$baseRank"
}

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
    $verifiedRank = [double]$verified.fields.'Microsoft.VSTS.Common.StackRank'
    $checks = @(
        ($verified.fields.'System.WorkItemType' -eq "User Story"), ($verified.fields.'System.State' -eq "Backlog"),
        ($verified.fields.'System.AreaPath' -eq $area), ($verified.fields.'System.IterationPath' -eq $iteration),
        ($verified.fields.'System.Tags' -like "*AI-StoryWriting*"), ((Get-ParentId -WorkItem $verified) -eq $parentId),
        ($verified.fields.'System.Description' -eq $expected.Description), ($verified.fields.'Microsoft.VSTS.Common.AcceptanceCriteria' -eq $expected.AcceptanceCriteria)
    )
    if ($null -ne $priorMinRank) { $checks += ($verifiedRank -lt $priorMinRank) }
    if ($checks -contains $false) { throw "VERIFY failed for work item $createdId." }
    Write-Host "VERIFY id=$createdId url=$org/$project/_workitems/edit/$createdId type=$($verified.fields.'System.WorkItemType') state=$($verified.fields.'System.State') area=$($verified.fields.'System.AreaPath') iteration=$($verified.fields.'System.IterationPath') tags=$($verified.fields.'System.Tags') stackRank=$verifiedRank parent=$parentId"
}