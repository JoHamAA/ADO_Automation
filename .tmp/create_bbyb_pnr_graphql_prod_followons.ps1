$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"
$parentId = 2951268

$stories = @(
    @{
        Title = "PaxHub - BBYB - PNR GraphQL API - Production Readiness for Group Indicator Response"
        Description = '<div><b>Given</b> the PNR GraphQL API implementation adds the isGroupPnr response element for corporate and blockspaced-group PNRs<br><b>When</b> the team prepares the change for production release<br><b>Then</b> code, schema, configuration, testing, monitoring, access, dependency, and rollback readiness are reviewed and completed<br><b>And</b> the production release is approved with evidence that all supported GraphQL queries return the expected group indicator behavior</div><br><div><b>Context:</b> Prepare the PNR GraphQL API group-indicator enhancement for production. The implementation exposes isGroupPnr across the supported GraphQL queries and derives the value from the approved corporate or blockspacedgroup logic. This story covers production-readiness validation, release artifacts, operational checks, consumer impact, approvals, and a deployment plan; it does not perform the production deployment.</div>'
        AcceptanceCriteria = '<div><b>Confirm functional and schema readiness</b><br><b>Given</b> the isGroupPnr implementation and GraphQL schema changes are complete<br><b>When</b> production-readiness validation is performed<br><b>Then</b> all supported PNR GraphQL queries return the expected indicator for corporate, blockspaced-group, and ordinary PNRs<br><b>And</b> schema compatibility and representative test evidence are documented.</div><br><div><b>Validate deployment dependencies and rollback</b><br><b>Given</b> production deployment may depend on configuration, pipeline, access, downstream consumers, or coordinated releases<br><b>When</b> the release plan is reviewed<br><b>Then</b> dependencies, approvals, deployment steps, monitoring, rollback criteria, and owners are documented<br><b>And</b> unresolved blockers prevent production execution until explicitly addressed.</div><br><div><b>Handle unexpected production conditions safely</b><br><b>Given</b> upstream values, schema consumers, or runtime behavior may differ from test assumptions<br><b>When</b> readiness checks identify invalid data, errors, latency changes, or compatibility concerns<br><b>Then</b> the issue is recorded with impact, remediation, and decision ownership<br><b>And</b> no sensitive PNR data is exposed in logs or release evidence.</div><br><div><b>Complete operational and consumer readiness review</b><br><b>Given</b> the group indicator will be consumed by existing PNR GraphQL clients<br><b>When</b> the release is reviewed for production approval<br><b>Then</b> performance baseline, observability, support documentation, stakeholder communication, and consumer impact are assessed<br><b>And</b> the production deployment approval and planned validation window are recorded.</div>'
    }
    @{
        Title = "PaxHub - BBYB - PNR GraphQL API - PROD Deployment of Group Indicator Response"
        Description = '<div><b>Given</b> the PNR GraphQL API isGroupPnr enhancement has completed production-readiness validation and approval<br><b>When</b> the approved production deployment is executed<br><b>Then</b> the implementation and schema are deployed successfully and the group indicator is available through all supported PNR GraphQL queries<br><b>And</b> post-deployment validation confirms expected behavior without disrupting existing consumers</div><br><div><b>Context:</b> Deploy the approved isGroupPnr enhancement for the PNR GraphQL API to production. The release must preserve existing response behavior while exposing the indicator based on corporate or blockspacedgroup logic. Execute smoke and functional checks for group and ordinary PNRs, monitor service health and client impact, document deployment evidence, and follow the rollback plan if validation fails.</div>'
        AcceptanceCriteria = '<div><b>Deploy the approved GraphQL enhancement</b><br><b>Given</b> production-readiness approval and deployment artifacts are complete<br><b>When</b> the production release is executed through the approved pipeline or runbook<br><b>Then</b> the PNR GraphQL implementation and schema deploy successfully<br><b>And</b> deployment version, pipeline evidence, and release timing are recorded.</div><br><div><b>Validate group indicator behavior after deployment</b><br><b>Given</b> the production deployment has completed<br><b>When</b> smoke and functional validation runs for corporate, blockspaced-group, and ordinary PNRs<br><b>Then</b> isGroupPnr is returned correctly across all supported queries<br><b>And</b> existing response fields and consumer-compatible behavior remain intact.</div><br><div><b>Handle deployment or validation failure safely</b><br><b>Given</b> deployment, schema propagation, runtime, or post-deployment validation may fail<br><b>When</b> a release issue or unexpected production condition is detected<br><b>Then</b> the documented rollback or mitigation plan is executed with clear ownership and communication<br><b>And</b> errors, impact, and recovery evidence are captured without exposing sensitive PNR data.</div><br><div><b>Confirm operational performance and support handoff</b><br><b>Given</b> the new response element is live for PNR GraphQL consumers<br><b>When</b> post-deployment monitoring is completed<br><b>Then</b> response time, error rate, availability, logs, alerts, and downstream consumer signals are compared with baseline expectations<br><b>And</b> support documentation and final deployment status are published.</div>'
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
    $verifiedParentId = Get-ParentId -WorkItem $verified
    $checks = @(
        ($verified.id -eq $createdId), ($null -ne $expected), ($verified.fields.'System.WorkItemType' -eq "User Story"),
        ($verified.fields.'System.State' -eq "Backlog"), ($verified.fields.'System.AreaPath' -eq $area),
        ($verified.fields.'System.IterationPath' -eq $iteration), ($verified.fields.'System.Tags' -like "*AI-StoryWriting*"),
        ($verifiedParentId -eq $parentId), ($verified.fields.'System.Description' -eq $expected.Description),
        ($verified.fields.'Microsoft.VSTS.Common.AcceptanceCriteria' -eq $expected.AcceptanceCriteria)
    )
    if ($null -ne $priorMinRank) { $checks += ([double]$verified.fields.'Microsoft.VSTS.Common.StackRank' -lt $priorMinRank) }
    if ($checks -contains $false) { throw "VERIFY failed for work item $createdId." }
    Write-Host "VERIFY id=$createdId url=$org/$project/_workitems/edit/$createdId type=$($verified.fields.'System.WorkItemType') state=$($verified.fields.'System.State') area=$($verified.fields.'System.AreaPath') iteration=$($verified.fields.'System.IterationPath') tags=$($verified.fields.'System.Tags') stackRank=$($verified.fields.'Microsoft.VSTS.Common.StackRank') parent=$verifiedParentId description=true acceptanceCriteria=true"
}