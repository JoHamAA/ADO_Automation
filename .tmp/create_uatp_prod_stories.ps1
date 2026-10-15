$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"
$parentId = 3107427
$iteration = "PassengerDataHub"
$sourceId = 3161812

$stories = @(
    @{
        Title = "PaxHub - Migration to MongoDB - PNR Graph API - isUATPPnr - PROD Readiness"
        Description = '<div><b>Given</b> story 3161812 adds the isUATPPnr boolean to PNR Graph API using active and historical booking remarks<br><b>When</b> the team prepares the change for production<br><b>Then</b> code, schema, testing, dependencies, approvals, monitoring, and rollback plans are reviewed and documented<br><b>And</b> the release is approved only after outstanding risks and owners are recorded</div><br><div><b>Context:</b> Prepare the production release of isUATPPnr from story 3161812. The value is true when bkg reservation.remarks.remark.remarkLines.remarkLine.text or bkg_hist history.historyTransaction.remarkHistory.ord_rmk_txt contains *TP103770, *TP10378, or *TP10379; otherwise false. Confirm Customer PNR API compatibility, Apollo GraphQL schema publication, representative PNR validation (including ADDGBK where permitted), load-test comparison to baseline, production access and configuration, operational monitoring, release approvals, and a rollback plan. This story covers readiness, not the production deployment.</div>'
        Criteria = '<div><b>Confirm implementation and schema readiness</b><br><b>Given</b> story 3161812 has been implemented in NONPROD<br><b>When</b> production readiness is reviewed<br><b>Then</b> code, pipeline artifacts, production configuration, access, Apollo schema contract, and approvals are checked<br><b>And</b> isUATPPnr boolean behavior is documented for active and historical remark matching and the false default.</div><br><div><b>Validate representative data and error handling</b><br><b>Given</b> PNRs may include matching, nonmatching, missing, or malformed active and historical remarks<br><b>When</b> regression tests are reviewed against Customer PNR API behavior<br><b>Then</b> representative cases confirm the expected true or false result without failing the PNR response<br><b>And</b> unexpected data shapes are diagnosed without logging sensitive PNR content.</div><br><div><b>Approve release documentation and rollback plan</b><br><b>Given</b> a production release is being planned<br><b>When</b> the release package is reviewed<br><b>Then</b> the Apollo schema publication steps, deployment order, smoke checks, monitoring, communications, and rollback criteria are documented<br><b>And</b> owners, dependencies, and unresolved risks are approved before deployment.</div><br><div><b>Assess consumer and performance readiness</b><br><b>Given</b> existing GraphQL consumers must remain compatible<br><b>When</b> load and contract test evidence is compared with the pre-change baseline<br><b>Then</b> response time, error rates, resource usage, and consumer compatibility are documented<br><b>And</b> any material regression has an agreed mitigation before production rollout.</div>'
    },
    @{
        Title = "PaxHub - Migration to MongoDB - PNR Graph API - isUATPPnr - PROD Deployment"
        Description = '<div><b>Given</b> the production readiness review for the isUATPPnr change from story 3161812 is approved<br><b>When</b> the PNR Graph API release is deployed to production<br><b>Then</b> the API and Apollo GraphQL schema are published in the approved sequence and the new boolean is validated in production<br><b>And</b> monitoring, rollback, and stakeholder communication protect existing PNR consumers</div><br><div><b>Context:</b> Deploy the production implementation of isUATPPnr from story 3161812 after readiness approval. Confirm true for permitted PNRs with *TP103770, *TP10378, or *TP10379 in active bkg or historical bkg_hist remarks and false for nonmatching or absent remarks. Use ADDGBK as a reference where access permits, validate the Apollo schema and Customer PNR API compatibility, monitor latency and errors, and record deployment evidence and rollback decisions.</div>'
        Criteria = '<div><b>Deploy approved API and Apollo schema</b><br><b>Given</b> production readiness, approvals, and release artifacts are complete<br><b>When</b> the approved pipeline or runbook is executed<br><b>Then</b> the PNR Graph API build and isUATPPnr boolean schema are deployed to production in the agreed order<br><b>And</b> the deployed versions and change record are captured.</div><br><div><b>Validate production UATP response behavior</b><br><b>Given</b> approved production test cases include matching and nonmatching active or historical remarks<br><b>When</b> post-deployment smoke checks call the PNR Graph API<br><b>Then</b> isUATPPnr is true for *TP103770, *TP10378, or *TP10379 and false when no match exists<br><b>And</b> the GraphQL response and Apollo schema remain compatible with existing consumers.</div><br><div><b>Respond to failures without exposing PNR data</b><br><b>Given</b> deployment, schema publication, data validation, or downstream checks can fail<br><b>When</b> an issue is detected during rollout<br><b>Then</b> the documented mitigation or rollback is applied and the incident is escalated to release owners<br><b>And</b> diagnostics and communications do not expose sensitive booking information.</div><br><div><b>Monitor release and record operational evidence</b><br><b>Given</b> the production release has completed<br><b>When</b> operational checks and a baseline comparison are performed<br><b>Then</b> response latency, error rate, resource use, and representative PNR results are recorded<br><b>And</b> release notes, schema documentation, support handoff, and deployment outcome are updated.</div>'
    }
)

function Invoke-AzJson {
    param([string[]]$Arguments)
    $result = & az @Arguments | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw "az command failed: $($Arguments[0..2] -join ' ')" }
    return $result
}

$parent = Invoke-AzJson -Arguments @("boards", "work-item", "show", "--id", "$parentId", "--organization", $org, "--output", "json")
if ($parent.fields.'System.TeamProject' -ne $project -or $parent.fields.'System.WorkItemType' -ne "Feature") { throw "PARENT $parentId must be a Feature in $project." }
$area = $parent.fields.'System.AreaPath'
$parentTags = @($parent.fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$tags = @($parentTags + "AI-StoryWriting" | Sort-Object -Unique) -join "; "
Write-Host "PARENT id=$parentId area=$area tags=$tags source=$sourceId"

foreach ($story in $stories) {
    $escapedTitle = $story.Title.Replace("'", "''")
    $duplicateWiql = "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.Title] = '$escapedTitle'"
    $duplicates = @(Invoke-AzJson -Arguments @("boards", "query", "--organization", $org, "--project", $project, "--wiql", $duplicateWiql, "--output", "json") | Where-Object { $_.id })
    if ($duplicates.Count -gt 0) { Write-Host "DUPLICATE duplicate_exists id=$($duplicates[0].id) url=$org/$project/_workitems/edit/$($duplicates[0].id)"; continue }
    Write-Host "DUPLICATE none title=$($story.Title)"

    $rankWiql = "SELECT [System.Id], [Microsoft.VSTS.Common.StackRank] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.IterationPath] UNDER '$iteration' ORDER BY [Microsoft.VSTS.Common.StackRank] ASC"
    $rankItems = @(Invoke-AzJson -Arguments @("boards", "query", "--organization", $org, "--project", $project, "--wiql", $rankWiql, "--output", "json"))
    $rankValues = @($rankItems | ForEach-Object { $_.fields.'Microsoft.VSTS.Common.StackRank' } | Where-Object { $null -ne $_ -and "$_" -ne "" })
    $priorMinRank = $null
    $parsedRank = 0.0
    if ($rankValues.Count -gt 0 -and [double]::TryParse("$($rankValues[0])", [ref]$parsedRank)) { $priorMinRank = $parsedRank }
    $stackRank = if ($null -eq $priorMinRank) { -1000000 } else { $priorMinRank - 1000 }
    Write-Host "RANK priorMin=$priorMinRank new=$stackRank"

    $created = Invoke-AzJson -Arguments @("boards", "work-item", "create", "--organization", $org, "--project", $project, "--type", "User Story", "--title", $story.Title, "--area", $area, "--iteration", $iteration, "--fields", "System.Description=$($story.Description)", "Microsoft.VSTS.Common.AcceptanceCriteria=$($story.Criteria)", "Microsoft.VSTS.Scheduling.StoryPoints=0", "Microsoft.VSTS.Common.Priority=2", "AAIT.Ready=Yes", "AAIT.WorkType=4. Software / UX", "System.State=Backlog", "System.Tags=$tags", "Microsoft.VSTS.Common.StackRank=$stackRank", "--output", "json")
    if (-not $created.id) { throw "CREATE missing ID; query exact title before retry: $($story.Title)" }
    Write-Host "CREATE id=$($created.id) title=$($story.Title)"

    $null = Invoke-AzJson -Arguments @("boards", "work-item", "relation", "add", "--id", "$($created.id)", "--organization", $org, "--relation-type", "parent", "--target-id", "$parentId", "--output", "json")
    Write-Host "LINK child=$($created.id) parent=$parentId"

    $verified = Invoke-AzJson -Arguments @("boards", "work-item", "show", "--id", "$($created.id)", "--organization", $org, "--expand", "all", "--output", "json")
    $verifiedParents = @($verified.relations | Where-Object { $_.rel -eq "System.LinkTypes.Hierarchy-Reverse" } | ForEach-Object { [int]($_.url.Split('/')[-1]) })
    $verifiedTags = @($verified.fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() })
    $checks = @(
        ($verified.id -eq $created.id), ($verified.fields.'System.Title' -eq $story.Title),
        ($verified.fields.'System.WorkItemType' -eq "User Story"), ($verified.fields.'System.State' -eq "Backlog"),
        ($verified.fields.'System.AreaPath' -eq $area), ($verified.fields.'System.IterationPath' -eq $iteration),
        (@($parentTags + "AI-StoryWriting" | Where-Object { $_ -notin $verifiedTags }).Count -eq 0),
        ($verifiedParents.Count -eq 1 -and $verifiedParents[0] -eq $parentId),
        ($verified.fields.'System.Description' -eq $story.Description),
        ($verified.fields.'Microsoft.VSTS.Common.AcceptanceCriteria' -eq $story.Criteria),
        ([double]$verified.fields.'Microsoft.VSTS.Common.StackRank' -eq $stackRank)
    )
    if ($null -ne $priorMinRank) { $checks += ([double]$verified.fields.'Microsoft.VSTS.Common.StackRank' -lt $priorMinRank) }
    if ($checks -contains $false) { throw "VERIFY failed for id=$($created.id); inspect exact ID before retry." }
    Write-Host "VERIFY id=$($created.id) url=$org/$project/_workitems/edit/$($created.id) title=$($story.Title) type=User Story state=Backlog area=$area iteration=$iteration tags=$($verified.fields.'System.Tags') stackRank=$stackRank parent=$parentId description=true acceptanceCriteria=true"
}