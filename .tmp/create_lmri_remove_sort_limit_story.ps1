$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"
$parentId = 3171294
$title = "PaxHub - Migration to MongoDB - LMRI GraphQL API - Refactor Code to Remove Sorting and Limiting in Query"

$description = '<div><b>Given</b> the LMRI GraphQL API currently applies sorting and limiting in the MongoDB query<br><b>When</b> the query implementation is refactored as part of the MongoDB migration<br><b>Then</b> query-level sorting and limiting are removed because they are not required by the API flow<br><b>And</b> loyalty test-account filtering is handled by the approved in-memory cache solution without changing normal consumer behavior</div><br><div><b>Context:</b> Refactor the LMRI GraphQL API query code to remove unnecessary sort and limit operations. The in-memory cache solution for configured Loyalty Test accounts will handle that filtering behavior separately. Preserve the required query predicates, response contract, pagination or downstream expectations that remain applicable, and document the resulting behavior. Execute load testing after the change and compare results with the pre-change baseline to identify any performance impact or further tuning needs.</div>'

$acceptanceCriteria = '<div><b>Remove unnecessary sorting and limiting from the query</b><br><b>Given</b> the LMRI GraphQL API query currently performs sort and limit operations that are not required<br><b>When</b> the query code is refactored<br><b>Then</b> query-level sorting and limiting are removed from the MongoDB access path<br><b>And</b> required filters, joins or lookups, response mapping, and supported consumer semantics remain intact.</div><br><div><b>Preserve loyalty test-account filtering behavior</b><br><b>Given</b> configured Loyalty Test accounts are filtered through the approved Caffeine in-memory cache solution<br><b>When</b> the LMRI API processes requests for configured and ordinary accounts<br><b>Then</b> test-account handling continues to return the established no-trips behavior and ordinary accounts continue through the normal flow<br><b>And</b> the refactor does not reintroduce query-based sorting or limiting as a substitute for cache filtering.</div><br><div><b>Handle query and cache edge cases safely</b><br><b>Given</b> query results may be empty, large, unordered, delayed, or affected by cache availability and malformed request data<br><b>When</b> the refactored API executes<br><b>Then</b> it returns a stable contract-compliant response or clear error without system instability<br><b>And</b> diagnostics identify failures without exposing loyalty account or booking data.</div><br><div><b>Validate performance after the refactor</b><br><b>Given</b> the query change may affect response time, throughput, resource usage, and downstream call volume<br><b>When</b> the implementation is load tested after deployment to the approved NONPROD environment<br><b>Then</b> response time, throughput, error rate, and relevant resource metrics are compared with the pre-change baseline<br><b>And</b> any regression or tuning action is documented before release.</div>'

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

$escapedTitle = $title.Replace("'", "''")
$duplicateWiql = "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.Title] = '$escapedTitle'"
$duplicates = @(az boards query --organization $org --project $project --wiql $duplicateWiql --output json | ConvertFrom-Json)
if ($duplicates.Count -gt 0) { throw "DUPLICATE duplicate_exists title=$title id=$($duplicates[0].id) url=$org/$project/_workitems/edit/$($duplicates[0].id)" }
Write-Host "DUPLICATE none title=$title"

$rankWiql = "SELECT [System.Id], [Microsoft.VSTS.Common.StackRank] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.IterationPath] UNDER '$iteration' ORDER BY [Microsoft.VSTS.Common.StackRank] ASC"
$rankItems = @(az boards query --organization $org --project $project --wiql $rankWiql --output json | ConvertFrom-Json)
$rankValues = @($rankItems | ForEach-Object { $_.fields.'Microsoft.VSTS.Common.StackRank' } | Where-Object { $null -ne $_ })
if ($rankValues.Count -gt 0) {
    $priorMinRank = [double]$rankValues[0]
    $stackRank = $priorMinRank - 1000
    Write-Host "RANK priorMin=$priorMinRank new=$stackRank"
} else {
    $priorMinRank = $null
    $stackRank = -1000000
    Write-Host "RANK priorMin=unavailable fallback=$stackRank"
}

$created = az boards work-item create --organization $org --project $project --type "User Story" --title $title --area $area --iteration $iteration --fields "System.Description=$description" "Microsoft.VSTS.Common.AcceptanceCriteria=$acceptanceCriteria" "Microsoft.VSTS.Scheduling.StoryPoints=0" "Microsoft.VSTS.Common.Priority=2" "AAIT.Ready=Yes" "AAIT.WorkType=4. Software / UX" "System.State=Backlog" "System.Tags=$tags" "Microsoft.VSTS.Common.StackRank=$stackRank" --output json | ConvertFrom-Json
if (-not $created.id) { throw "CREATE failed to return a work item ID." }
Write-Host "CREATE id=$($created.id) rank=$stackRank title=$title"

az boards work-item relation add --id $created.id --organization $org --relation-type parent --target-id $parentId --output json | Out-Null
Write-Host "LINK child=$($created.id) parent=$parentId"

$verified = az boards work-item show --id $created.id --organization $org --expand all --output json | ConvertFrom-Json
$verifiedParentId = Get-ParentId -WorkItem $verified
$verifiedRank = [double]$verified.fields.'Microsoft.VSTS.Common.StackRank'
$checks = @(
    ($verified.id -eq $created.id), ($verified.fields.'System.Title' -eq $title),
    ($verified.fields.'System.WorkItemType' -eq "User Story"), ($verified.fields.'System.State' -eq "Backlog"),
    ($verified.fields.'System.AreaPath' -eq $area), ($verified.fields.'System.IterationPath' -eq $iteration),
    ($verified.fields.'System.Tags' -like "*AI-StoryWriting*"), ($verifiedParentId -eq $parentId),
    ($verified.fields.'System.Description' -eq $description), ($verified.fields.'Microsoft.VSTS.Common.AcceptanceCriteria' -eq $acceptanceCriteria)
)
if ($null -ne $priorMinRank) { $checks += ($verifiedRank -lt $priorMinRank) }
if ($checks -contains $false) { throw "VERIFY failed for work item $($created.id)." }
Write-Host "VERIFY id=$($created.id) url=$org/$project/_workitems/edit/$($created.id) type=$($verified.fields.'System.WorkItemType') state=$($verified.fields.'System.State') area=$($verified.fields.'System.AreaPath') iteration=$($verified.fields.'System.IterationPath') tags=$($verified.fields.'System.Tags') stackRank=$verifiedRank parent=$verifiedParentId description=true acceptanceCriteria=true"