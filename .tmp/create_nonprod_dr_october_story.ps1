$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"
$parentId = 3171324
$iteration = "PassengerDataHub"
$title = "PaxHub - Disaster Recovery (DR) - NONPROD - Prepare and Validate October 2026 Failover and Fallback"
$description = '<div><b>Given</b> PaxHub is scheduled for a NONPROD Disaster Recovery exercise with failover to Azure West on 7 Oct 2026 and fallback to Azure East on 8 Oct 2026<br><b>When</b> the team prepares and participates in both DR transitions<br><b>Then</b> PaxHub application health, Event Hub and MongoDB integrations, and critical consumer flows are validated in the active region<br><b>And</b> the results, recovery gaps, and follow-up actions are documented and communicated</div><br><div><b>Context:</b> The PaxHub 4Q roadmap calls for annual Event Hub and MongoDB DR preparation during the Oct 5-9 NONPROD window. Confirm exercise times and ownership with DR coordinators; times are currently TBD. Coordinate a reversible failover to Azure West on Oct 7 and fallback to Azure East on Oct 8, with preflight checks, representative smoke tests, monitoring, and evidence of recovered service. Scope is NONPROD only; production failover/fallback planned for Oct 21-22 is a separate activity and is not included in this story.</div>'
$criteria = '<div><b>Prepare the NONPROD DR runbook and dependencies</b><br><b>Given</b> the Oct 7-8 NONPROD exercise is approaching<br><b>When</b> readiness is reviewed with DR and application owners<br><b>Then</b> applicable PaxHub services, Event Hub components, MongoDB services, access, regional endpoints, contacts, change windows, and success criteria are identified<br><b>And</b> the Azure West failover and Azure East fallback steps, monitoring, communication plan, and safe recovery actions are documented before execution.</div><br><div><b>Validate failover to Azure West on October 7</b><br><b>Given</b> the baseline health and approved NONPROD failover plan are recorded<br><b>When</b> the exercise shifts traffic and dependencies to Azure West on 7 Oct 2026<br><b>Then</b> representative PaxHub requests, Event Hub publishing or consumption, MongoDB connectivity, and critical downstream integrations are checked in the active region<br><b>And</b> service health, latency, error rates, data continuity, and observed failures are recorded.</div><br><div><b>Validate fallback to Azure East on October 8</b><br><b>Given</b> the NONPROD failover exercise has completed<br><b>When</b> the approved fallback returns traffic and dependencies to Azure East on 8 Oct 2026<br><b>Then</b> application routing, Event Hub processing, MongoDB reads or writes as applicable, and representative consumer flows are verified after recovery<br><b>And</b> any delayed, duplicate, or missing events and outstanding regional dependencies are documented for resolution.</div><br><div><b>Handle failures and protect test data</b><br><b>Given</b> a regional switch, integration, or data consistency check can fail<br><b>When</b> the exercise reveals an outage, unresponsive dependency, or unexpected data<br><b>Then</b> the team follows the agreed mitigation or abort path, identifies an owner, and notifies DR stakeholders without leaving NONPROD in an unknown state<br><b>And</b> diagnostics and evidence exclude sensitive passenger or credential data.</div><br><div><b>Publish DR evidence and follow-up work</b><br><b>Given</b> both NONPROD transitions are complete<br><b>When</b> results are reviewed with stakeholders<br><b>Then</b> test evidence, measured recovery outcomes, exceptions, lessons learned, runbook updates, and remediation owners are recorded<br><b>And</b> any unresolved risks affecting the separate production DR exercise are shared before its Oct 21-22 window.</div>'

function Invoke-AzJson {
    param([string[]]$Arguments)
    $result = & az @Arguments | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw "az command failed: $($Arguments[0..2] -join ' ')" }
    return $result
}

$parent = Invoke-AzJson -Arguments @("boards", "work-item", "show", "--id", "$parentId", "--organization", $org, "--output", "json")
if ($parent.fields.'System.TeamProject' -ne $project -or $parent.fields.'System.WorkItemType' -ne "Feature") { throw "PARENT $parentId must be a Feature in $project" }
$area = $parent.fields.'System.AreaPath'
$parentTags = @($parent.fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$tags = @($parentTags + "AI-StoryWriting" | Sort-Object -Unique) -join "; "
Write-Host "PARENT id=$parentId title=$($parent.fields.'System.Title') area=$area tags=$tags"

$escapedTitle = $title.Replace("'", "''")
$duplicateWiql = "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.Title] = '$escapedTitle'"
$duplicates = @(Invoke-AzJson -Arguments @("boards", "query", "--organization", $org, "--project", $project, "--wiql", $duplicateWiql, "--output", "json") | Where-Object { $_.id })
if ($duplicates.Count -gt 0) { Write-Host "DUPLICATE duplicate_exists id=$($duplicates[0].id) url=$org/$project/_workitems/edit/$($duplicates[0].id)"; exit 10 }
Write-Host "DUPLICATE none title=$title"

$rankWiql = "SELECT [System.Id], [Microsoft.VSTS.Common.StackRank] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.IterationPath] UNDER '$iteration' ORDER BY [Microsoft.VSTS.Common.StackRank] ASC"
$rankItems = @(Invoke-AzJson -Arguments @("boards", "query", "--organization", $org, "--project", $project, "--wiql", $rankWiql, "--output", "json"))
$rankValues = @($rankItems | ForEach-Object { $_.fields.'Microsoft.VSTS.Common.StackRank' } | Where-Object { $null -ne $_ -and "$_" -ne "" })
$priorMinRank = $null
$parsedRank = 0.0
if ($rankValues.Count -gt 0 -and [double]::TryParse("$($rankValues[0])", [ref]$parsedRank)) { $priorMinRank = $parsedRank }
$stackRank = if ($null -eq $priorMinRank) { -1000000 } else { $priorMinRank - 1000 }
Write-Host "RANK priorMin=$priorMinRank new=$stackRank"

$created = Invoke-AzJson -Arguments @("boards", "work-item", "create", "--organization", $org, "--project", $project, "--type", "User Story", "--title", $title, "--area", $area, "--iteration", $iteration, "--fields", "System.Description=$description", "Microsoft.VSTS.Common.AcceptanceCriteria=$criteria", "Microsoft.VSTS.Scheduling.StoryPoints=0", "Microsoft.VSTS.Common.Priority=2", "AAIT.Ready=Yes", "AAIT.WorkType=4. Software / UX", "System.State=Backlog", "System.Tags=$tags", "Microsoft.VSTS.Common.StackRank=$stackRank", "--output", "json")
if (-not $created.id) { throw "CREATE missing ID; check exact title before retry: $title" }
Write-Host "CREATE id=$($created.id) title=$title"

$null = Invoke-AzJson -Arguments @("boards", "work-item", "relation", "add", "--id", "$($created.id)", "--organization", $org, "--relation-type", "parent", "--target-id", "$parentId", "--output", "json")
Write-Host "LINK child=$($created.id) parent=$parentId"

$verified = Invoke-AzJson -Arguments @("boards", "work-item", "show", "--id", "$($created.id)", "--organization", $org, "--expand", "all", "--output", "json")
$verifiedParents = @($verified.relations | Where-Object { $_.rel -eq "System.LinkTypes.Hierarchy-Reverse" } | ForEach-Object { [int]($_.url.Split('/')[-1]) })
$verifiedTags = @($verified.fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() })
$checks = @(
    ($verified.id -eq $created.id), ($verified.fields.'System.Title' -eq $title),
    ($verified.fields.'System.WorkItemType' -eq "User Story"), ($verified.fields.'System.State' -eq "Backlog"),
    ($verified.fields.'System.AreaPath' -eq $area), ($verified.fields.'System.IterationPath' -eq $iteration),
    (@($parentTags + "AI-StoryWriting" | Where-Object { $_ -notin $verifiedTags }).Count -eq 0),
    ($verifiedParents.Count -eq 1 -and $verifiedParents[0] -eq $parentId),
    ($verified.fields.'System.Description'.Replace(' </div>','</div>') -eq $description),
    ($verified.fields.'Microsoft.VSTS.Common.AcceptanceCriteria'.Replace(' </div>','</div>') -eq $criteria),
    ([double]$verified.fields.'Microsoft.VSTS.Common.StackRank' -eq $stackRank)
)
if ($null -ne $priorMinRank) { $checks += ([double]$verified.fields.'Microsoft.VSTS.Common.StackRank' -lt $priorMinRank) }
if ($checks -contains $false) { throw "VERIFY failed for id=$($created.id); inspect exact ID before reporting." }
Write-Host "VERIFY id=$($created.id) url=$org/$project/_workitems/edit/$($created.id) title=$title type=User Story state=Backlog area=$area iteration=$iteration tags=$($verified.fields.'System.Tags') stackRank=$stackRank parent=$parentId description=true acceptanceCriteria=true"