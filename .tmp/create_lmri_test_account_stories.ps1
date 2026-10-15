$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"
$parentId = 3171294

$stories = @(
    @{
        Title = "PaxHub - Migration to MongoDB - LMRI GraphQL API - Integrate and Read Config File with AADV Test Accounts"
        Description = '<div><b>Given</b> certain AAdvantage loyalty accounts are reserved for client testing and can contain many bookings<br><b>When</b> the LMRI GraphQL API is configured for the MongoDB migration<br><b>Then</b> the API loads the maintained test-account list from a configuration file and makes it available through an in-memory Caffeine cache<br><b>And</b> the configuration can be maintained without embedding the account list in application logic</div><br><div><b>Context:</b> Create and integrate a configuration file containing the AAdvantage numbers of accounts used by clients to test PROD functionality. Source the maintained list from ECDOPRIME.EDPD_LYLTY_TEST_ACCTS using LYLTY_ACCT_ID and Status, and implement startup loading consistent with the referenced CaffeineCacheConfig and CacheStartupLoader patterns from ch-cupid-service-v3. The cached collection should be named listOfKnownTestAadvAccounts or follow the approved equivalent. Configuration, access, refresh, failure behavior, and secret/data-handling expectations must be documented.</div>'
        AcceptanceCriteria = '<div><b>Define and load the test-account configuration</b><br><b>Given</b> the approved SQL source query returns AAdvantage test accounts and status values<br><b>When</b> the configuration is created and the LMRI service starts<br><b>Then</b> the account identifiers and applicable status values are represented in the approved configuration format<br><b>And</b> startup loading makes the list available to the API through the Caffeine in-memory cache.</div><br><div><b>Handle missing, invalid, or unavailable configuration safely</b><br><b>Given</b> the file is missing, malformed, contains invalid account identifiers, or cannot be loaded<br><b>When</b> the service initializes or refreshes the cache<br><b>Then</b> the failure is logged with actionable diagnostics and the service follows the approved fail-safe behavior<br><b>And</b> a partial or stale list is not silently treated as authoritative without the documented policy.</div><br><div><b>Document configuration and cache operations</b><br><b>Given</b> the test-account list must be maintained over time<br><b>When</b> the implementation is delivered<br><b>Then</b> the file location, schema, SQL source, status interpretation, startup loading, cache name, refresh behavior, and update procedure are documented<br><b>And</b> environment-specific configuration is externalized rather than hardcoded.</div><br><div><b>Protect account data and validate startup behavior</b><br><b>Given</b> the list contains loyalty account identifiers used in PROD testing<br><b>When</b> configuration loading and service startup are tested<br><b>Then</b> access follows least privilege, identifiers are not exposed unnecessarily in logs, and cache initialization is deterministic<br><b>And</b> unit or integration coverage verifies valid entries, duplicate handling, status filtering, and cache availability.</div>'
    }
    @{
        Title = "PaxHub - Migration to MongoDB - LMRI GraphQL API - Update Response to Show No Trips for Test Accounts"
        Description = '<div><b>Given</b> the LMRI GraphQL API has a maintained cached list of AAdvantage test accounts<br><b>When</b> a client submits a request using an account in that list<br><b>Then</b> the API returns a successful response that represents no trips found for the test account<br><b>And</b> the response prevents the test account booking volume from causing unnecessary downstream performance impact</div><br><div><b>Context:</b> Update LMRI GraphQL API response handling for AAdvantage accounts defined in the configuration file. When a request contains a configured test account, do not retrieve or expose its bookings; return the established no-trips response contract. Preserve normal MongoDB-backed trip behavior for accounts not in the list, and ensure the behavior is compatible with existing consumers and the cached list loaded by the companion story.</div>'
        AcceptanceCriteria = '<div><b>Return no trips for configured test accounts</b><br><b>Given</b> the requested AAdvantage account is present in the configured Caffeine cache list<br><b>When</b> the LMRI GraphQL API processes the request<br><b>Then</b> it returns the established successful no-trips response contract<br><b>And</b> it avoids unnecessary booking retrieval and does not expose the test account bookings.</div><br><div><b>Preserve normal behavior for non-test accounts</b><br><b>Given</b> the requested account is not present in the configured test-account list<br><b>When</b> the LMRI GraphQL API processes the request<br><b>Then</b> it continues to use the approved MongoDB flow and returns eligible trips according to existing business rules<br><b>And</b> the change does not alter pagination, schema, or response semantics for ordinary accounts.</div><br><div><b>Handle cache and request edge cases safely</b><br><b>Given</b> the cache is empty, unavailable, stale, or the request contains a missing, malformed, or unauthorized account identifier<br><b>When</b> the API evaluates test-account behavior<br><b>Then</b> it follows documented fail-safe and validation behavior with a clear, contract-compliant response<br><b>And</b> it does not accidentally classify ordinary accounts as test accounts or disclose sensitive details.</div><br><div><b>Validate consumer compatibility and performance protection</b><br><b>Given</b> downstream clients consume the LMRI GraphQL response and test accounts may contain many bookings<br><b>When</b> functional, regression, and performance tests are executed<br><b>Then</b> configured test accounts consistently produce no-trips responses while non-test accounts remain compatible<br><b>And</b> request volume, latency, downstream calls, and error metrics demonstrate the intended performance protection.</div>'
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
    $verifiedRank = [double]$verified.fields.'Microsoft.VSTS.Common.StackRank'
    $checks = @(
        ($verified.id -eq $createdId),
        ($null -ne $expected),
        ($verified.fields.'System.WorkItemType' -eq "User Story"),
        ($verified.fields.'System.State' -eq "Backlog"),
        ($verified.fields.'System.AreaPath' -eq $area),
        ($verified.fields.'System.IterationPath' -eq $iteration),
        ($verified.fields.'System.Tags' -like "*AI-StoryWriting*"),
        ((Get-ParentId -WorkItem $verified) -eq $parentId),
        ($verified.fields.'System.Description' -eq $expected.Description),
        ($verified.fields.'Microsoft.VSTS.Common.AcceptanceCriteria' -eq $expected.AcceptanceCriteria)
    )
    if ($null -ne $priorMinRank) { $checks += ($verifiedRank -lt $priorMinRank) }
    if ($checks -contains $false) { throw "VERIFY failed for work item $createdId." }
    Write-Host "VERIFY id=$createdId url=$org/$project/_workitems/edit/$createdId type=$($verified.fields.'System.WorkItemType') state=$($verified.fields.'System.State') area=$($verified.fields.'System.AreaPath') iteration=$($verified.fields.'System.IterationPath') tags=$($verified.fields.'System.Tags') stackRank=$verifiedRank parent=$parentId description=true acceptanceCriteria=true"
}