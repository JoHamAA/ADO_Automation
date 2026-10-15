$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"
$parentId = 3054458
$spikeId = 3036371
$iteration = "PassengerDataHub"
$agentNexusInstructions = "https://github.com/AAInternal/aa-commercial-agent-skills#onboarding-a-team-consumer-quickstart"
$workItemBaseUrl = "$org/$project/_workitems/edit"

$applications = @(
    @{ Name = "ch-pnr-details"; Kind = "backend application"; AgentNexusDoneId = 3087658 },
    @{ Name = "ch-passenger-manifest"; Kind = "backend application"; AgentNexusDoneId = $null },
    @{ Name = "ch-customer-pnr"; Kind = "backend application"; AgentNexusDoneId = $null },
    @{ Name = "ch-backend-oms-flight-stats"; Kind = "backend application"; AgentNexusDoneId = $null },
    @{ Name = "ch-backend-oms-night-flight-stats"; Kind = "backend application"; AgentNexusDoneId = $null },
    @{ Name = "ch-backend-pdp-email"; Kind = "backend application"; AgentNexusDoneId = $null },
    @{ Name = "ch-backend-kbyg-email"; Kind = "backend application"; AgentNexusDoneId = 3087628 },
    @{ Name = "ch-backend-kbyg-term-info"; Kind = "backend application"; AgentNexusDoneId = 3087631 },
    @{ Name = "ch-backend-international-outbound"; Kind = "backend application"; AgentNexusDoneId = $null },
    @{ Name = "PNR Graph API"; Kind = "Graph API"; AgentNexusDoneId = $null }
)

function Get-ParentId {
    param($WorkItem)
    $relation = @($WorkItem.relations | Where-Object { $_.rel -eq "System.LinkTypes.Hierarchy-Reverse" }) | Select-Object -First 1
    if (-not $relation) { return $null }
    return [int]($relation.url.Split('/')[-1])
}

function Normalize-RichText {
    param([string]$Value)
    return $Value -replace '\s+</div>', '</div>'
}

function Get-ExactDuplicate {
    param([string]$Title)
    $escapedTitle = $Title.Replace("'", "''")
    $wiql = "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.Title] = '$escapedTitle'"
    return @(az boards query --organization $org --project $project --wiql $wiql --output json | ConvertFrom-Json)
}

function New-StoryDefinition {
    param($Application)
    $name = $Application.Name
    $kind = $Application.Kind
    $title = "PaxHub - New Tier Initiative - $name - Implement NONPROD Pre-Gold Tier Support"

    if ($null -ne $Application.AgentNexusDoneId) {
        $doneId = [int]$Application.AgentNexusDoneId
        $agentContext = "Agent Nexus onboarding is already complete under <a href=`"$workItemBaseUrl/$doneId`">work item $doneId</a>; this story must confirm that onboarding remains active for the NTI changes rather than duplicate completed work."
        $agentCriterion = "<div><b>Confirm completed Agent Nexus onboarding remains active</b><br><b>Given</b> Agent Nexus onboarding for $name was completed under <a href=`"$workItemBaseUrl/$doneId`">work item $doneId</a><br><b>When</b> the NONPROD New Tier Initiative changes are built and validated<br><b>Then</b> the existing Agent Nexus registration is confirmed active and scans cover the updated application repository<br><b>And</b> any new security findings are tracked through Agent Nexus without repeating the completed onboarding work.</div>"
    } else {
        $agentContext = "Agent Nexus onboarding must be completed in this story alongside the NTI implementation to avoid a separate, duplicative change."
        $agentCriterion = "<div><b>Onboard the application to Agent Nexus with the NTI change</b><br><b>Given</b> $name must be monitored through Agent Nexus<br><b>When</b> the NONPROD New Tier Initiative implementation is completed<br><b>Then</b> the application repository is onboarded using the <a href=`"$agentNexusInstructions`">Agent Nexus Onboarding Instructions</a> and successful registration is verified<br><b>And</b> future security findings are available for remediation through Agent Nexus without requiring a separate onboarding effort.</div>"
    }

    $description = "<div><b>Given</b> Sabre supports the New Tier Initiative and spike <a href=`"$workItemBaseUrl/$spikeId`">$spikeId</a> identified PaxHub tier-mapping impacts<br><b>When</b> the $name $kind processes loyalty tier data in NONPROD<br><b>Then</b> the approved Pre-Gold tier identifier is translated to the approved customer-facing status and exposed consistently through the application's existing contracts<br><b>And</b> existing tier behavior remains compatible for current consumers</div><br><div><b>Context:</b> Implement the New Tier Initiative changes for $name in NONPROD as part of the March 2027 initiative. Complete code, configuration, contract, test, dependency, and operational updates identified by spike $spikeId. $agentContext Reference: <a href=`"$agentNexusInstructions`">Agent Nexus Onboarding Instructions</a>.</div>"

    $acceptanceCriteria = "<div><b>Map and expose the approved Pre-Gold tier</b><br><b>Given</b> the approved new tier identifier and customer-facing value are available<br><b>When</b> $name processes a customer or PNR containing that identifier in NONPROD<br><b>Then</b> the identifier is translated to the approved Pre-Gold value in every impacted response or downstream message<br><b>And</b> the behavior is consistent with the mappings and endpoint impacts identified by spike $spikeId.</div><br><div><b>Preserve existing tiers and handle unexpected values safely</b><br><b>Given</b> existing loyalty tiers and unknown, missing, or malformed tier identifiers may be received<br><b>When</b> the updated mapping logic executes<br><b>Then</b> existing tiers retain their current behavior and unexpected values follow the approved fallback or error handling without service instability<br><b>And</b> logs and errors provide actionable diagnostics without exposing sensitive customer data.</div><br><div><b>Update contracts configuration and documentation</b><br><b>Given</b> tier support may affect application configuration, schemas, transformations, or consumer contracts<br><b>When</b> the $name implementation is completed<br><b>Then</b> all impacted configuration, API or message contracts, mapping references, automated tests, and support documentation are updated<br><b>And</b> dependencies, assumptions, rollout considerations, and consumer impacts are recorded.</div><br><div><b>Validate NONPROD behavior and nonfunctional readiness</b><br><b>Given</b> the NTI changes are deployed to the approved NONPROD environment<br><b>When</b> functional, regression, integration, performance, security, and reliability validation is executed<br><b>Then</b> Pre-Gold and existing-tier scenarios pass across impacted paths without unacceptable latency, error-rate, or availability regression<br><b>And</b> validation evidence and unresolved risks are documented before production planning.</div><br>$agentCriterion"

    return @{
        Name = $name
        Title = $title
        Description = $description
        AcceptanceCriteria = $acceptanceCriteria
    }
}

$parent = az boards work-item show --id $parentId --organization $org --expand all --output json | ConvertFrom-Json
if ($parent.fields.'System.TeamProject' -ne $project) { throw "PARENT $parentId is not in $project." }
if ($parent.fields.'System.WorkItemType' -ne "Feature") { throw "PARENT $parentId is not a Feature." }

$area = $parent.fields.'System.AreaPath'
$parentTags = @($parent.fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$allTags = @($parentTags)
$allTags += @("3Q26", "AI-StoryWriting", "Initiative", "NewTier")
$tags = @($allTags | Sort-Object -Unique) -join "; "
$stories = @($applications | ForEach-Object { New-StoryDefinition -Application $_ })
Write-Host "PARENT id=$parentId type=Feature area=$area iteration=$iteration tags=$tags spike=$spikeId stories=$($stories.Count)"

foreach ($story in $stories) {
    $duplicates = @(Get-ExactDuplicate -Title $story.Title)
    if ($duplicates.Count -gt 0) {
        $duplicateId = $duplicates[0].id
        throw "DUPLICATE duplicate_exists title=$($story.Title) id=$duplicateId url=$workItemBaseUrl/$duplicateId"
    }
    Write-Host "DUPLICATE preflight=none title=$($story.Title)"
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

$created = @()
for ($index = 0; $index -lt $stories.Count; $index++) {
    $story = $stories[$index]
    $duplicates = @(Get-ExactDuplicate -Title $story.Title)
    if ($duplicates.Count -gt 0) {
        $duplicateId = $duplicates[0].id
        throw "DUPLICATE duplicate_exists immediately_before_create title=$($story.Title) id=$duplicateId url=$workItemBaseUrl/$duplicateId"
    }
    Write-Host "DUPLICATE immediate=none title=$($story.Title)"

    $stackRank = $baseRank - ($index * 100)
    $createdItem = az boards work-item create --organization $org --project $project --type "User Story" --title $story.Title --area $area --iteration $iteration --fields "System.Description=$($story.Description)" "Microsoft.VSTS.Common.AcceptanceCriteria=$($story.AcceptanceCriteria)" "Microsoft.VSTS.Scheduling.StoryPoints=0" "Microsoft.VSTS.Common.Priority=2" "AAIT.Ready=Yes" "AAIT.WorkType=4. Software / UX" "System.State=Backlog" "System.Tags=$tags" "Microsoft.VSTS.Common.StackRank=$stackRank" --output json | ConvertFrom-Json
    if (-not $createdItem.id) { throw "CREATE failed for $($story.Title)." }
    $createdId = [int]$createdItem.id
    Write-Host "CREATE id=$createdId rank=$stackRank title=$($story.Title)"

    az boards work-item relation add --id $createdId --organization $org --relation-type parent --target-id $parentId --output json | Out-Null
    Write-Host "LINK child=$createdId parent=$parentId"
    $created += @{ Id = $createdId; StackRank = $stackRank; Story = $story }
}

foreach ($entry in $created) {
    $verified = az boards work-item show --id $entry.Id --organization $org --expand all --output json | ConvertFrom-Json
    $verifiedParentId = Get-ParentId -WorkItem $verified
    $verifiedTags = @($verified.fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
    $expectedTags = @($tags -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
    $checks = @(
        ($verified.id -eq $entry.Id),
        ($verified.fields.'System.Title' -eq $entry.Story.Title),
        ($verified.fields.'System.WorkItemType' -eq "User Story"),
        ($verified.fields.'System.State' -eq "Backlog"),
        ($verified.fields.'System.AreaPath' -eq $area),
        ($verified.fields.'System.IterationPath' -eq $iteration),
        ($null -eq (Compare-Object $expectedTags $verifiedTags)),
        ($verifiedParentId -eq $parentId),
        ((Normalize-RichText $verified.fields.'System.Description') -eq (Normalize-RichText $entry.Story.Description)),
        ((Normalize-RichText $verified.fields.'Microsoft.VSTS.Common.AcceptanceCriteria') -eq (Normalize-RichText $entry.Story.AcceptanceCriteria)),
        ([double]$verified.fields.'Microsoft.VSTS.Common.StackRank' -eq [double]$entry.StackRank)
    )
    if ($null -ne $priorMinRank) {
        $checks += ([double]$verified.fields.'Microsoft.VSTS.Common.StackRank' -lt $priorMinRank)
    }
    if ($checks -contains $false) { throw "VERIFY failed for work item $($entry.Id)." }
    Write-Host "VERIFY id=$($entry.Id) url=$workItemBaseUrl/$($entry.Id) title=$($verified.fields.'System.Title') type=$($verified.fields.'System.WorkItemType') state=$($verified.fields.'System.State') area=$($verified.fields.'System.AreaPath') iteration=$($verified.fields.'System.IterationPath') tags=$($verified.fields.'System.Tags') stackRank=$($verified.fields.'Microsoft.VSTS.Common.StackRank') parent=$verifiedParentId description=true acceptanceCriteria=true"
}