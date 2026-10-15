$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"
$parentId = 3107210
$iteration = "PassengerDataHub"
$title = "PaxHub - Migration to MongoDB - IROP Phone Opt In - Analyze IROP App for KPASS and Event Hub Integration (Spike)"

$description = '<div><b>Given</b> the IROP Phone Opt In application currently queries SQLMI for specific PNRs and then calls a CNE service<br><b>When</b> the team investigates replacing SQLMI-dependent retrieval with an Event Hub-triggered flow and integration with KPASS<br><b>Then</b> the current application behavior, dependencies, data flow, and feasible future-state architecture are documented<br><b>And</b> the work needed to implement the agreed future state is captured in follow-on user stories</div><br><div><b>Context:</b> SQLMI is planned for decommissioning. This spike analyzes how IROP Phone Opt In currently selects PNRs from SQLMI and interacts with CNE, whether Event Hub events can trigger the application without SQLMI reads, and how KPASS would provide the required data or capabilities. Document feasibility, gaps, decisions, and migration steps; this is an investigation and story-definition effort, not an implementation of the proposed integration.</div>'

$acceptanceCriteria = '<div><b>Document the current IROP processing flow</b><br><b>Given</b> the existing IROP Phone Opt In application and its integrations are available for review<br><b>When</b> the spike examines how PNRs are selected from SQLMI and how the CNE service is invoked<br><b>Then</b> the current triggers, data inputs and outputs, SQLMI queries, CNE contract, and operational dependencies are documented<br><b>And</b> any unknowns or assumptions are called out for validation.</div><br><div><b>Assess the Event Hub and KPASS future state</b><br><b>Given</b> SQLMI is expected to be decommissioned<br><b>When</b> Event Hub-triggered processing and KPASS integration options are evaluated<br><b>Then</b> a proposed data flow identifies event source and contract, PNR selection and enrichment, KPASS responsibilities and interfaces, and the continuing role of CNE<br><b>And</b> feasibility, required changes, dependencies, migration approach, and any unresolved design decisions are documented without relying on SQLMI reads in the target state.</div><br><div><b>Evaluate resilience, security, and consumer impacts</b><br><b>Given</b> events or KPASS and CNE responses may be missing, delayed, duplicated, out of order, or unavailable<br><b>When</b> the proposed flow is reviewed with stakeholders<br><b>Then</b> error handling, retries or dead-letter behavior, idempotency, observability, and access to PNR data are assessed<br><b>And</b> impacts to existing IROP and CNE behavior, event volume, latency, and data protection are recorded.</div><br><div><b>Publish findings and create implementation stories</b><br><b>Given</b> the current state and future-state options have been analyzed<br><b>When</b> the spike is completed<br><b>Then</b> an accessible design or investigation document records the recommended approach, diagrams or data contracts as appropriate, open questions, and decisions<br><b>And</b> follow-on user stories are created and linked to the appropriate Feature for the agreed implementation, testing, rollout, and SQLMI dependency removal.</div>'

function Invoke-AzJson {
    param([string[]]$Arguments)
    $result = & az @Arguments | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw "az command failed: $($Arguments[0..2] -join ' ')" }
    return $result
}

$parent = Invoke-AzJson -Arguments @("boards", "work-item", "show", "--id", "$parentId", "--organization", $org, "--expand", "all", "--output", "json")
if ($parent.fields.'System.TeamProject' -ne $project -or $parent.fields.'System.WorkItemType' -ne "Feature") { throw "PARENT $parentId must be a Feature in $project." }
$area = $parent.fields.'System.AreaPath'
$parentTags = @($parent.fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$tags = @($parentTags + "AI-StoryWriting" | Sort-Object -Unique) -join "; "
Write-Host "PARENT id=$parentId title=$($parent.fields.'System.Title') area=$area iteration=$iteration tags=$tags"

$rankWiql = "SELECT [System.Id], [Microsoft.VSTS.Common.StackRank] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.IterationPath] UNDER '$iteration' ORDER BY [Microsoft.VSTS.Common.StackRank] ASC"
$rankItems = @(Invoke-AzJson -Arguments @("boards", "query", "--organization", $org, "--project", $project, "--wiql", $rankWiql, "--output", "json"))
$rankValues = @($rankItems | ForEach-Object { $_.fields.'Microsoft.VSTS.Common.StackRank' } | Where-Object { $null -ne $_ -and "$_" -ne "" })
$priorMinRank = $null
if ($rankValues.Count -gt 0) {
    $parsedRank = 0.0
    if ([double]::TryParse("$($rankValues[0])", [ref]$parsedRank)) { $priorMinRank = $parsedRank }
}
if ($null -ne $priorMinRank) {
    $stackRank = $priorMinRank - 1000
    Write-Host "RANK priorMin=$priorMinRank new=$stackRank"
} else {
    $stackRank = -1000000
    Write-Host "RANK priorMin=unavailable fallback=$stackRank"
}

$escapedTitle = $title.Replace("'", "''")
$duplicateWiql = "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.Title] = '$escapedTitle'"
$duplicates = @(Invoke-AzJson -Arguments @("boards", "query", "--organization", $org, "--project", $project, "--wiql", $duplicateWiql, "--output", "json") | Where-Object { $_.id })
if ($duplicates.Count -gt 0) { throw "DUPLICATE duplicate_exists id=$($duplicates[0].id) url=$org/$project/_workitems/edit/$($duplicates[0].id)" }
Write-Host "DUPLICATE none title=$title"

$created = Invoke-AzJson -Arguments @("boards", "work-item", "create", "--organization", $org, "--project", $project, "--type", "User Story", "--title", $title, "--area", $area, "--iteration", $iteration, "--fields", "System.Description=$description", "Microsoft.VSTS.Common.AcceptanceCriteria=$acceptanceCriteria", "Microsoft.VSTS.Scheduling.StoryPoints=0", "Microsoft.VSTS.Common.Priority=2", "AAIT.Ready=Yes", "AAIT.WorkType=4. Software / UX", "System.State=Backlog", "System.Tags=$tags", "Microsoft.VSTS.Common.StackRank=$stackRank", "--output", "json")
if (-not $created.id) { throw "CREATE missing ID; check exact title before any retry: $title" }
Write-Host "CREATE id=$($created.id) title=$title"

$null = Invoke-AzJson -Arguments @("boards", "work-item", "relation", "add", "--id", "$($created.id)", "--organization", $org, "--relation-type", "parent", "--target-id", "$parentId", "--output", "json")
Write-Host "LINK child=$($created.id) parent=$parentId"

$verified = Invoke-AzJson -Arguments @("boards", "work-item", "show", "--id", "$($created.id)", "--organization", $org, "--expand", "all", "--output", "json")
$verifiedParent = @($verified.relations | Where-Object { $_.rel -eq "System.LinkTypes.Hierarchy-Reverse" } | ForEach-Object { [int]($_.url.Split('/')[-1]) })
$verifiedRank = [double]$verified.fields.'Microsoft.VSTS.Common.StackRank'
$verifiedTags = @($verified.fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() })
$checks = @(
    ($verified.id -eq $created.id), ($verified.fields.'System.Title' -eq $title),
    ($verified.fields.'System.WorkItemType' -eq "User Story"), ($verified.fields.'System.State' -eq "Backlog"),
    ($verified.fields.'System.AreaPath' -eq $area), ($verified.fields.'System.IterationPath' -eq $iteration),
    (@($parentTags + "AI-StoryWriting" | Where-Object { $_ -notin $verifiedTags }).Count -eq 0),
    ($verifiedParent.Count -eq 1 -and $verifiedParent[0] -eq $parentId),
    ($verified.fields.'System.Description' -eq $description),
    ($verified.fields.'Microsoft.VSTS.Common.AcceptanceCriteria' -eq $acceptanceCriteria),
    ($verifiedRank -eq $stackRank)
)
if ($null -ne $priorMinRank) { $checks += ($verifiedRank -lt $priorMinRank) }
if ($checks -contains $false) { throw "VERIFY failed for id=$($created.id); check work item before reporting success." }
Write-Host "VERIFY id=$($created.id) url=$org/$project/_workitems/edit/$($created.id) title=$title type=$($verified.fields.'System.WorkItemType') state=$($verified.fields.'System.State') area=$($verified.fields.'System.AreaPath') iteration=$($verified.fields.'System.IterationPath') tags=$($verified.fields.'System.Tags') stackRank=$verifiedRank parent=$($verifiedParent[0]) description=true acceptanceCriteria=true"