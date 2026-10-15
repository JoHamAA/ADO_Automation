$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "DataEngineering"
$parentId = 3150151
$assignee = "799691@corpaa.aa.com"

$stories = @(
    @{
        Title = "Journey Inspirations - Distressed Inventory - Tailored Destination Functional End-to-End Data Testing and Validation - NONPROD"
        Description = '<div><b>Given</b> the Tailored Destination data flow is deployed in the approved Non-Prod environment<br><b>When</b> functional end-to-end data testing is executed across the source, North Star gold layer, and downstream delivery path<br><b>Then</b> data completeness, transformations, customer/PNR associations, and expected outputs are validated<br><b>And</b> defects and evidence are documented before the flow is considered ready for load testing or production promotion</div><br><div><b>Context:</b> Perform functional end-to-end data testing and validation for Tailored Destination in Non-Prod. Validate representative records across the approved certified source data, transformations, gold data product, and downstream output. Confirm expected record counts, required fields, business rules, data quality, and traceability without treating CCDP or downstream context assembly as the source of truth for source-domain data.</div>'
        AcceptanceCriteria = '<div><b>Validate end-to-end data flow and transformations</b><br><b>Given</b> approved Non-Prod source data and deployed Tailored Destination pipeline components are available<br><b>When</b> a representative end-to-end functional run is performed<br><b>Then</b> records flow through each expected stage and transformed outputs match approved business rules<br><b>And</b> source-to-target counts and key field mappings are reconciled.</div><br><div><b>Verify data quality and edge cases</b><br><b>Given</b> source data can contain missing, duplicate, late, invalid, or boundary-value records<br><b>When</b> test cases are executed<br><b>Then</b> required fields, keys, null handling, deduplication, filtering, and exception behavior match the approved design<br><b>And</b> invalid records are surfaced with actionable diagnostics without corrupting valid outputs.</div><br><div><b>Capture test evidence and defects</b><br><b>Given</b> functional validation is complete<br><b>When</b> results are reviewed<br><b>Then</b> test cases, datasets or safe references, expected and actual results, reconciliation evidence, and defects are documented<br><b>And</b> unresolved defects have owners and are tracked before the Non-Prod flow is accepted.</div><br><div><b>Confirm Non-Prod readiness and data safeguards</b><br><b>Given</b> testing uses customer-context and journey-related data<br><b>When</b> the Non-Prod validation is performed<br><b>Then</b> access, privacy, logging, and environment safeguards follow approved requirements<br><b>And</b> functional results and known limitations are reviewed with engineering and product stakeholders before load testing or promotion.</div>'
    }
    @{
        Title = "Journey Inspirations - Distressed Inventory - Tailored Destination End-to-End Load Testing and Validation - NONPROD"
        Description = '<div><b>Given</b> functional end-to-end testing has established that the Tailored Destination data flow is correct in Non-Prod<br><b>When</b> controlled load testing is run against representative regular and peak workloads<br><b>Then</b> throughput, latency, error rate, capacity, and data correctness are measured across the end-to-end flow<br><b>And</b> performance results are compared with agreed baselines and objectives to identify tuning needs</div><br><div><b>Context:</b> Execute end-to-end load testing and validation for Tailored Destination in Non-Prod. Define representative workload profiles, concurrency, ramp-up, duration, data volume, and assertions. Monitor relevant pipeline and platform metrics while ensuring tests do not create uncontrolled load or modify production data. Document results, bottlenecks, and tuning or retest actions.</div>'
        AcceptanceCriteria = '<div><b>Run controlled regular and peak workload profiles</b><br><b>Given</b> the functional Non-Prod data flow is ready and workload assumptions are agreed<br><b>When</b> regular and high-peak load profiles are executed end to end<br><b>Then</b> test configuration captures volume, concurrency, ramp-up, duration, and execution conditions<br><b>And</b> runs remain controlled within approved Non-Prod capacity and access limits.</div><br><div><b>Measure performance and data correctness under load</b><br><b>Given</b> the pipeline processes representative Tailored Destination data at target load<br><b>When</b> load tests execute<br><b>Then</b> throughput, latency, error rate, resource utilization, and stage-level timings are captured<br><b>And</b> output counts, required fields, key integrity, and transformation correctness remain within agreed tolerances.</div><br><div><b>Handle overload and failure conditions</b><br><b>Given</b> workloads may exceed capacity or encounter timeouts, retries, and partial failures<br><b>When</b> those conditions occur during testing<br><b>Then</b> failures are observable and recovery, retry, and back-pressure behavior follows the approved design<br><b>And</b> runs do not silently lose data or leave target outputs in an inconsistent state.</div><br><div><b>Compare results and document tuning actions</b><br><b>Given</b> load-test metrics and baseline objectives are available<br><b>When</b> performance results are analyzed<br><b>Then</b> results are compared against baseline and target criteria with bottlenecks and capacity risks identified<br><b>And</b> tuning actions, owners, retest requirements, and readiness conclusions are documented.</div>'
    }
    @{
        Title = "Journey Inspirations - Distressed Inventory - Tailored Destination End-to-End Data Testing and Validation - PROD"
        Description = '<div><b>Given</b> the Tailored Destination data flow has passed required Non-Prod validation and received production approval<br><b>When</b> controlled end-to-end data validation is performed in Production after deployment<br><b>Then</b> production outputs, mappings, required fields, and business rules are confirmed using approved safe validation procedures<br><b>And</b> production data integrity and service stability are preserved</div><br><div><b>Context:</b> Perform end-to-end data testing and validation for Tailored Destination in Production after an approved release. Use approved production-safe checks and representative monitoring or reconciliation; avoid destructive testing and unauthorized changes to customer or operational data. Compare production outcomes with approved Non-Prod expectations, capture evidence, and escalate discrepancies through the production support process.</div>'
        AcceptanceCriteria = '<div><b>Validate production outputs using approved checks</b><br><b>Given</b> the Tailored Destination release is approved and deployed to Production<br><b>When</b> production-safe end-to-end validation and reconciliation are executed<br><b>Then</b> expected stages, mappings, required fields, and business rules are confirmed using approved data checks<br><b>And</b> observed output counts and key measures are reconciled with approved expectations.</div><br><div><b>Protect production data and service stability</b><br><b>Given</b> validation runs against live production systems and data<br><b>When</b> checks are performed<br><b>Then</b> only authorized, non-destructive procedures and approved access are used<br><b>And</b> validation does not trigger uncontrolled workloads, alter source-of-record data, or expose sensitive customer information.</div><br><div><b>Handle production discrepancies and failures</b><br><b>Given</b> production data may differ from Non-Prod expectations or a check may fail<br><b>When</b> an anomaly, data-quality issue, or service error is detected<br><b>Then</b> the issue is recorded with impact, evidence, owner, and escalation path<br><b>And</b> the approved incident, mitigation, or rollback process is followed where required.</div><br><div><b>Complete production validation evidence and handoff</b><br><b>Given</b> production validation is complete<br><b>When</b> results are reviewed with engineering, product, and operations<br><b>Then</b> test evidence, reconciliation results, monitoring observations, and known limitations are documented<br><b>And</b> production acceptance or follow-up actions are recorded before closing the validation.</div>'
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
Write-Host "PARENT id=$parentId type=Feature area=$area iteration=$iteration tags=$tags assignee=$assignee"

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
    $created = az boards work-item create --organization $org --project $project --type "User Story" --title $story.Title --area $area --iteration $iteration --assigned-to $assignee --fields "System.Description=$($story.Description)" "Microsoft.VSTS.Common.AcceptanceCriteria=$($story.AcceptanceCriteria)" "Microsoft.VSTS.Scheduling.StoryPoints=0" "Microsoft.VSTS.Common.Priority=2" "AAIT.Ready=Yes" "AAIT.WorkType=4. Software / UX" "System.State=Backlog" "System.Tags=$tags" "Microsoft.VSTS.Common.StackRank=$stackRank" --output json | ConvertFrom-Json
    if (-not $created.id) { throw "CREATE failed for $($story.Title)." }
    $createdIds += $created.id
    Write-Host "CREATE id=$($created.id) rank=$stackRank title=$($story.Title) assignee=$assignee"
    az boards work-item relation add --id $created.id --organization $org --relation-type parent --target-id $parentId --output json | Out-Null
    Write-Host "LINK child=$($created.id) parent=$parentId"
}

foreach ($createdId in $createdIds) {
    $verified = az boards work-item show --id $createdId --organization $org --expand all --output json | ConvertFrom-Json
    $expected = @($stories | Where-Object { $_.Title -eq $verified.fields.'System.Title' }) | Select-Object -First 1
    $verifiedAssignedTo = [string]$verified.fields.'System.AssignedTo'
    $checks = @(
        ($verified.id -eq $createdId), ($null -ne $expected), ($verified.fields.'System.WorkItemType' -eq "User Story"),
        ($verified.fields.'System.State' -eq "Backlog"), ($verified.fields.'System.AreaPath' -eq $area),
        ($verified.fields.'System.IterationPath' -eq $iteration), ($verified.fields.'System.Tags' -like "*AI-StoryWriting*"),
        ((Get-ParentId -WorkItem $verified) -eq $parentId), ($verifiedAssignedTo -match [regex]::Escape($assignee)),
        ($verified.fields.'System.Description' -eq $expected.Description),
        ($verified.fields.'Microsoft.VSTS.Common.AcceptanceCriteria' -eq $expected.AcceptanceCriteria)
    )
    if ($null -ne $priorMinRank) { $checks += ([double]$verified.fields.'Microsoft.VSTS.Common.StackRank' -lt $priorMinRank) }
    if ($checks -contains $false) { throw "VERIFY failed for work item $createdId." }
    Write-Host "VERIFY id=$createdId url=$org/$project/_workitems/edit/$createdId type=$($verified.fields.'System.WorkItemType') state=$($verified.fields.'System.State') area=$($verified.fields.'System.AreaPath') iteration=$($verified.fields.'System.IterationPath') tags=$($verified.fields.'System.Tags') stackRank=$($verified.fields.'Microsoft.VSTS.Common.StackRank') parent=$parentId assignedTo=$verifiedAssignedTo description=true acceptanceCriteria=true"
}