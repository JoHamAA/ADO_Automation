param([switch]$ValidateOnly, [string]$RequestPath)

$ErrorActionPreference = 'Stop'
$org = 'https://dev.azure.com/AmericanAirlines'
$project = 'PassengerDataHub'
$parentId = 3171324
$iteration = 'PassengerDataHub'
$title = 'PaxHub - OPS - CNE Payload - Replace CUSTOMERHUB with PaxHub in Requesting Product and Requesting System'
$description = '<div><b>Given</b> PaxHub sends CNE payloads whose Requesting Product or Requesting System values include the legacy product identifier CUSTOMERHUB<br><b>When</b> CNE confirms compatibility and the approved payload change is implemented<br><b>Then</b> CUSTOMERHUB is replaced with the exact value PaxHub in both fields<br><b>And</b> existing CNE and CHECKIN values, notification delivery, routing, monitoring, and support behavior remain unchanged</div><br><div><b>Context:</b> Track this as a low-priority enhancement/reference-data correction, not a bug or a CNE contact-only update. Current Requesting Product values: CUSTOMERHUB, CNE. Current Requesting System values: CHECKIN, CUSTOMERHUB. Replace only CUSTOMERHUB with PaxHub, preserving CNE, CHECKIN, all unrelated values, and the existing payload representation. The proposed current-product identifier is PaxHub, not PASSENGER DATA HUB. Sridharan Periyasamy identified these values as part of the payload transmitted from PaxHub to CNE. Identify the actual field paths and every applicable producer/code/configuration mapping; do not assume the comma-separated examples specify the wire format. CNE confirmation of the exact PaxHub value and its processing/routing compatibility is a prerequisite to implementation. Include NONPROD integration testing, production deployment and verification, and rollback to the previous values if needed. Source: RE: Action Requested: CNE Contact Updates for Resiliency Week.</div>'
$criteria = '<div><b>Document field usage and obtain CNE approval</b><br><b>Given</b> Requesting Product and Requesting System are present in payloads sent from PaxHub to CNE<br><b>When</b> the team reviews producers, mappings, payload contracts, and CNE processing with the CNE team<br><b>Then</b> the actual field paths, current values, affected producers, and routing or integration dependencies are documented<br><b>And</b> CNE approval of the exact replacement value PaxHub in both fields is recorded before implementation; unresolved compatibility questions block implementation.</div><br><div><b>Replace CUSTOMERHUB in both fields without changing other values</b><br><b>Given</b> CNE has approved PaxHub and the existing Requesting Product values include CUSTOMERHUB and CNE while Requesting System values include CHECKIN and CUSTOMERHUB<br><b>When</b> each affected PaxHub producer constructs a CNE payload<br><b>Then</b> CUSTOMERHUB becomes PaxHub in both fields with the exact approved spelling and case<br><b>And</b> CNE, CHECKIN, unrelated values, payload structure, and other fields are preserved, with automated tests covering both replacements and unaffected cases.</div><br><div><b>Handle missing values and CNE failures without delivery regression</b><br><b>Given</b> either field is missing, null, contains unexpected values, or CNE rejects a payload or is unavailable<br><b>When</b> PaxHub builds or transmits the notification payload<br><b>Then</b> unrelated identifiers are not rewritten and missing or unexpected values follow the documented existing validation behavior<br><b>And</b> existing error reporting, retry, and failure-recovery behavior is preserved without introducing lost or duplicate notifications, and diagnostics do not expose sensitive payload data.</div><br><div><b>Update payload contracts and operational references</b><br><b>Given</b> the replacement mappings and CNE compatibility requirements are approved<br><b>When</b> the change is implemented<br><b>Then</b> affected code, applicable configuration, payload schemas or contract documentation, and representative examples describe PaxHub in both fields<br><b>And</b> monitoring references, support documentation, rollout steps, and rollback instructions are updated where impacted.</div><br><div><b>Validate CNE processing and downstream behavior in NONPROD</b><br><b>Given</b> the updated producers are deployed to NONPROD and representative notification payloads exercise both fields and unchanged CNE and CHECKIN values<br><b>When</b> end-to-end notifications are sent and processed by CNE<br><b>Then</b> CNE confirms successful acceptance and processing of PaxHub in both fields<br><b>And</b> evidence demonstrates no regression in delivery, routing, integrations, monitoring, or support processes and is reviewed before production rollout.</div><br><div><b>Deploy to production and verify the updated identifiers</b><br><b>Given</b> CNE approval, NONPROD validation, and the production rollout and rollback plan are complete<br><b>When</b> the approved change is deployed to production<br><b>Then</b> representative production payloads show PaxHub instead of CUSTOMERHUB in both fields while CNE and CHECKIN remain unchanged<br><b>And</b> successful CNE processing, notification delivery, routing, and monitoring are verified with recorded evidence, with rollback used if agreed acceptance checks fail.</div>'

$priority = 4
$requiredValues = @('Requesting Product', 'Requesting System', 'CUSTOMERHUB', 'PaxHub', 'CNE', 'CHECKIN')
$outputDirectoryName = 'pax_cne_payload_3171324'
if ($RequestPath) {
    $request = Get-Content $RequestPath -Raw | ConvertFrom-Json
    if ($null -ne $request.parentId) {
        $parentId = [int]$request.parentId
        if ($parentId -le 0) { throw 'Invalid parent Feature ID.' }
    }
    $title = $request.title
    $description = $request.description
    $criteria = $request.acceptanceCriteria
    $priority = [int]$request.priority
    $requiredValues = @($request.requiredValues)
    $outputDirectoryName = $request.outputDirectoryName
    if ($title.Length -lt 18 -or $priority -lt 1 -or $priority -gt 4 -or $outputDirectoryName -notmatch '^[a-z0-9_]+$') { throw 'Invalid story request settings.' }
}
if ([regex]::Matches($criteria, '<b>Given</b>').Count -ne 6 -or $criteria -match 'Scenario:|Scenario [0-9]|Happy Path|Negative Path') { throw 'Invalid Gherkin criteria.' }
foreach ($value in $requiredValues) {
    if (-not $description.Contains($value) -or -not $criteria.Contains($value)) { throw "Missing requested value: $value" }
}
if ($ValidateOnly) { Write-Host "PASS content: title=$title priority=$priority requiredValues=verified six Gherkin criteria."; exit 0 }

$outputDirectory = Join-Path $env:TEMP $outputDirectoryName
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

function Invoke-AzJson {
    param([string[]]$Arguments, [string]$Name)
    $outputPath = Join-Path $outputDirectory "$Name.json"
    & az @Arguments --output json | Out-File -FilePath $outputPath -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw "az command failed: $Name. No automatic retry." }
    $raw = Get-Content $outputPath -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        if ($Arguments[1] -eq 'query') { return @() }
        throw "Missing output: $Name. Inspect saved records before retrying."
    }
    $result = $raw | ConvertFrom-Json
    return $result
}

$parent = Invoke-AzJson @('boards', 'work-item', 'show', '--id', "$parentId", '--organization', $org) 'parent'
if ($parent.fields.'System.TeamProject' -ne $project -or $parent.fields.'System.WorkItemType' -ne 'Feature') { throw 'Parent must be a Feature in PassengerDataHub.' }
$area = $parent.fields.'System.AreaPath'
$parentTags = @($parent.fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$expectedTags = @($parentTags + 'AI-StoryWriting' | Sort-Object -Unique)
$tags = $expectedTags -join '; '
Write-Host "PARENT id=$parentId area=$area tags=$tags title=$title priority=$priority iteration=$iteration"
$iterationNode = Invoke-AzJson @('boards', 'iteration', 'project', 'list', '--organization', $org, '--project', $project, '--depth', '0') 'iteration'
if ($iterationNode.name -ne $iteration) { throw 'Shared backlog iteration validation failed.' }

$rankWiql = "SELECT [System.Id], [Microsoft.VSTS.Common.StackRank] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.IterationPath] UNDER '$iteration' AND [System.WorkItemType] = 'User Story' ORDER BY [Microsoft.VSTS.Common.StackRank] ASC"
$rankItems = Invoke-AzJson @('boards', 'query', '--organization', $org, '--project', $project, '--wiql', $rankWiql) 'rank'
$numericRanks = @($rankItems | ForEach-Object {
    $value = $_.fields.'Microsoft.VSTS.Common.StackRank'
    $parsed = 0.0
    if ($null -ne $value -and [double]::TryParse([string]$value, [ref]$parsed) -and -not [double]::IsNaN($parsed) -and -not [double]::IsInfinity($parsed)) { $parsed }
})
$priorMinimum = $null
if ($numericRanks.Count) { $priorMinimum = ($numericRanks | Measure-Object -Minimum).Minimum }
$fallback = $null -eq $priorMinimum
$rank = if ($fallback) { -1000000000000.0 } else { [Math]::Floor($priorMinimum) - 1000 }
$rankText = $rank.ToString('R', [System.Globalization.CultureInfo]::InvariantCulture)
Write-Host "RANK priorMinimum=$priorMinimum assigned=$rankText fallback=$fallback"

$escapedTitle = $title.Replace("'", "''")
$duplicateWiql = "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.IterationPath] UNDER '$iteration' AND [System.WorkItemType] = 'User Story' AND [System.Title] = '$escapedTitle'"
$duplicates = @(Invoke-AzJson @('boards', 'query', '--organization', $org, '--project', $project, '--wiql', $duplicateWiql) 'duplicate' | Where-Object { $_.id })
if ($duplicates.Count) { Write-Host "DUPLICATE duplicate_exists id=$($duplicates[0].id) url=$org/$project/_workitems/edit/$($duplicates[0].id)"; exit 10 }
Write-Host 'DUPLICATE none'

try {
    $created = Invoke-AzJson @('boards', 'work-item', 'create', '--organization', $org, '--project', $project, '--type', 'User Story', '--title', $title, '--area', $area, '--iteration', $iteration, '--fields', "System.Description=$description", "Microsoft.VSTS.Common.AcceptanceCriteria=$criteria", 'Microsoft.VSTS.Scheduling.StoryPoints=0', "Microsoft.VSTS.Common.Priority=$priority", 'AAIT.Ready=Yes', 'AAIT.WorkType=4. Software / UX', 'System.State=Backlog', "System.Tags=$tags", "Microsoft.VSTS.Common.StackRank=$rankText") 'created'
    if (-not $created.id) { throw 'CREATE response missing ID.' }
} catch {
    $creationError = $_
    $matches = @(Invoke-AzJson @('boards', 'query', '--organization', $org, '--project', $project, '--wiql', $duplicateWiql) 'ambiguous_create' | Where-Object { $_.id })
    foreach ($match in $matches) { Write-Host "CREATE ambiguous id=$($match.id) url=$org/$project/_workitems/edit/$($match.id)" }
    throw $creationError
}
Write-Host "CREATE id=$($created.id)"
$null = Invoke-AzJson @('boards', 'work-item', 'relation', 'add', '--id', "$($created.id)", '--organization', $org, '--relation-type', 'parent', '--target-id', "$parentId") 'linked'
Write-Host "LINK child=$($created.id) parent=$parentId"
$verified = Invoke-AzJson @('boards', 'work-item', 'show', '--id', "$($created.id)", '--organization', $org, '--expand', 'relations') 'verified'
$fields = $verified.fields
$parents = @($verified.relations | Where-Object rel -eq 'System.LinkTypes.Hierarchy-Reverse')
$actualTags = @($fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$checks = @(
    ($verified.id -eq $created.id), ($fields.'System.Title' -ceq $title), ($fields.'System.WorkItemType' -eq 'User Story'),
    ($fields.'System.State' -eq 'Backlog'), ($fields.'System.AreaPath' -eq $area), ($fields.'System.IterationPath' -eq $iteration),
    (@(Compare-Object $expectedTags $actualTags -CaseSensitive).Count -eq 0),
    ($parents.Count -eq 1 -and $parents[0].url.Split('/')[-1] -eq "$parentId"),
    (($fields.'System.Description' -replace '\s+(?=</div>)', '') -ceq $description),
    (($fields.'Microsoft.VSTS.Common.AcceptanceCriteria' -replace '\s+(?=</div>)', '') -ceq $criteria),
    ([Math]::Abs([double]$fields.'Microsoft.VSTS.Common.StackRank' - $rank) -le 0.000001),
    ($fields.'Microsoft.VSTS.Scheduling.StoryPoints' -eq 0), ($fields.'Microsoft.VSTS.Common.Priority' -eq $priority),
    ($fields.'AAIT.Ready' -eq 'Yes'), ($fields.'AAIT.WorkType' -eq '4. Software / UX')
)
if (-not $fallback) { $checks += ([double]$fields.'Microsoft.VSTS.Common.StackRank' -lt $priorMinimum) }
if ($checks -contains $false) { throw "VERIFY failed for id=$($created.id). Do not recreate." }
Write-Host "VERIFY id=$($created.id) url=$org/$project/_workitems/edit/$($created.id) state=Backlog area=$area iteration=$iteration tags=$($fields.'System.Tags') rank=$($fields.'Microsoft.VSTS.Common.StackRank') parent=$parentId priority=$priority description=persisted acceptanceCriteria=persisted fallback=$fallback"
Write-Host 'DONE exit=0'