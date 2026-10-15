$ErrorActionPreference = 'Stop'
$org = 'https://dev.azure.com/AmericanAirlines'
$project = 'DataEngineering'
$parentId = 3150151
$title = 'Journey Inspirations - Distressed Inventory - Tailored Destination Prod Readiness and Infrastructure Setup'
$iteration = 'DataEngineering\Comm Data Eng Bus Analytics 1'
$outputDirectory = Join-Path $env:TEMP 'tailored_destination_prod_readiness'
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$description = '<div><b>Given</b> Tailored Destination (Journey Inspirations) distressed inventory production testing is tentatively planned for October 6-8, 2026, subject to satisfactory Non-Prod load-test results<br><b>When</b> the required production infrastructure, service authentication, access, and environment configuration are provisioned and validated<br><b>Then</b> the engineering team has the infrastructure readiness needed to support approved production testing<br><b>And</b> production test execution remains gated by the October 5, 2026 readiness decision and required approvals</div><br><div><b>Context:</b> Following standup, production testing is tentatively planned for October 6 through October 8, with further clarity expected on Monday, October 5 after reviewing Non-Prod load-test results. Prepare production Event Hub resources, service credentials for authentication, network connectivity, environment-specific configuration, monitoring, and supporting dependencies identified in the approved infrastructure checklist. Coordinate with platform and downstream teams and document blockers, ownership, and readiness evidence. This story prepares infrastructure; it does not authorize production testing or duplicate production end-to-end testing story 3184312. Non-Prod load testing story 3184311 provides an input to the readiness decision.</div>'
$acceptanceCriteria = '<div><b>Provision and validate production Event Hub infrastructure</b><br><b>Given</b> approved infrastructure requirements and available Non-Prod load-test findings<br><b>When</b> production resources are provisioned with the platform team<br><b>Then</b> the Event Hub namespace, event hub, required consumer groups, partitioning, retention, capacity, and identified supporting dependencies are configured against approved requirements<br><b>And</b> availability and production connectivity are validated with evidence, with remaining capacity decisions tracked before test authorization.</div><br><div><b>Validate secure production service authentication and access</b><br><b>Given</b> production publishers and approved consumers require service authentication<br><b>When</b> approved service identities and credential references are configured and validated<br><b>Then</b> authorized services authenticate successfully with least-privilege permissions and required network access<br><b>And</b> credentials are held in the approved secret store with ownership and expiry or rotation expectations documented, without secrets in code, logs, or story attachments.</div><br><div><b>Block readiness on unresolved infrastructure and authentication failures</b><br><b>Given</b> provisioning, permissions, credentials, or network dependencies may be missing or invalid<br><b>When</b> readiness validation encounters a failure or unauthorized access attempt<br><b>Then</b> the failure is recorded with sanitized actionable diagnostics, remediation ownership, and required resolution<br><b>And</b> unresolved critical failures block readiness without bypassing access controls or destabilizing production services.</div><br><div><b>Document production configuration and operational ownership</b><br><b>Given</b> production infrastructure and service access have been prepared<br><b>When</b> environment configuration and the readiness runbook are finalized<br><b>Then</b> approved environment-specific configuration references, resource identifiers, access references, dependency inventory, validation steps, monitoring and alerting, support ownership, and rollback or disablement steps are documented<br><b>And</b> configuration is externalized through approved environment or contract mechanisms and contains no hardcoded secrets.</div><br><div><b>Assess consumer impact and record the production readiness decision</b><br><b>Given</b> the October 6-8, 2026 production testing window is tentative and depends on Non-Prod load-test results<br><b>When</b> approved non-disruptive connectivity and smoke checks are reviewed with platform and downstream stakeholders before the planned window<br><b>Then</b> readiness evidence, load-test-based capacity considerations, event contract compatibility, consumer group and retention expectations, monitoring coverage, and outstanding risks are recorded<br><b>And</b> the October 5 go/no-go decision and required approvals determine whether testing can proceed; unresolved blockers or deferred approval are communicated without claiming production readiness.</div>'

az boards work-item show --id $parentId --organization $org --expand relations --output json > (Join-Path $outputDirectory 'parent.json')
if ($LASTEXITCODE -ne 0) { throw 'Parent lookup failed.' }
$parent = Get-Content (Join-Path $outputDirectory 'parent.json') -Raw | ConvertFrom-Json
if ($parent.fields.'System.TeamProject' -ne $project -or $parent.fields.'System.WorkItemType' -ne 'Feature') { throw 'Parent project or type does not match.' }
$area = $parent.fields.'System.AreaPath'
$expectedTags = @(@($parent.fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) + 'AI-StoryWriting' + 'Journey Inspirations' + 'Distressed Inventory' | Sort-Object -Unique)
$tags = $expectedTags -join '; '
Write-Host "PARENT id=$parentId project=$project area=$area"
az boards work-item show --id 3184312 --organization $org --output json > (Join-Path $outputDirectory 'assignee.json')
if ($LASTEXITCODE -ne 0) { throw 'Assignee lookup failed.' }
$identity = (Get-Content (Join-Path $outputDirectory 'assignee.json') -Raw | ConvertFrom-Json).fields.'System.AssignedTo'
if ($identity.displayName -ne 'Tanna, Piyush' -or -not $identity.uniqueName) { throw 'Confirmed assignee could not be resolved.' }
$assignee = $identity.uniqueName
az boards iteration project list --organization $org --project $project --depth 2 --output json > (Join-Path $outputDirectory 'iterations.json')
if ($LASTEXITCODE -ne 0) { throw 'Iteration lookup failed.' }
$nodes = @(Get-Content (Join-Path $outputDirectory 'iterations.json') -Raw | ConvertFrom-Json)
$iterationFound = $false
while ($nodes.Count -gt 0) {
    $node = $nodes[0]
    $nodes = @($nodes | Select-Object -Skip 1)
    if ($node.path -eq '\DataEngineering\Iteration\Comm Data Eng Bus Analytics 1') { $iterationFound = $true }
    $nodes += @($node.children | Where-Object { $null -ne $_ })
}
if (-not $iterationFound) { throw "Requested iteration does not exist: $iteration" }
$rankWiql = "SELECT [System.Id], [Microsoft.VSTS.Common.StackRank] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.AreaPath] = '$area' AND [System.IterationPath] UNDER '$iteration' ORDER BY [Microsoft.VSTS.Common.StackRank] ASC"
az boards query --organization $org --project $project --wiql $rankWiql --output json > (Join-Path $outputDirectory 'rank.json')
if ($LASTEXITCODE -ne 0) { throw 'Backlog rank query failed.' }
$rankItems = @(Get-Content (Join-Path $outputDirectory 'rank.json') -Raw | ConvertFrom-Json)
$priorMinimum = $null
$rankFallback = $false
foreach ($item in $rankItems) {
    $rankValue = $item.fields.'Microsoft.VSTS.Common.StackRank'
    if ($null -eq $rankValue) { continue }
    $parsedRank = 0.0
    if ([double]::TryParse([string]$rankValue, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsedRank) -and -not [double]::IsNaN($parsedRank) -and -not [double]::IsInfinity($parsedRank)) {
        if ($null -eq $priorMinimum -or $parsedRank -lt $priorMinimum) { $priorMinimum = $parsedRank }
    } else { $rankFallback = $true }
}
if ($null -eq $priorMinimum) { $rankFallback = $true; $stackRank = -1000000000000.0 } else { $stackRank = $priorMinimum - 1000.0 }
if ($rankFallback) { $stackRank = [Math]::Min($stackRank, -1000000000000.0) }
$rankText = $stackRank.ToString('R', [System.Globalization.CultureInfo]::InvariantCulture)
Write-Host "RANK priorMin=$priorMinimum new=$rankText fallback=$rankFallback"
$escapedTitle = $title.Replace("'", "''")
$duplicateWiql = "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.IterationPath] UNDER '$project' AND [System.WorkItemType] = 'User Story' AND [System.Title] = '$escapedTitle'"
az boards query --organization $org --project $project --wiql $duplicateWiql --output json > (Join-Path $outputDirectory 'duplicate.json')
if ($LASTEXITCODE -ne 0) { throw 'Exact duplicate check failed; no creation attempted.' }
$duplicates = @(Get-Content (Join-Path $outputDirectory 'duplicate.json') -Raw | ConvertFrom-Json)
if ($duplicates.Count -gt 0) {
    foreach ($duplicate in $duplicates) { Write-Host "DUPLICATE duplicate_exists id=$($duplicate.id) url=$org/$project/_workitems/edit/$($duplicate.id)" }
    exit 10
}
Write-Host 'DUPLICATE none'
az boards work-item create --organization $org --project $project --type 'User Story' --title $title --area $area --iteration $iteration --assigned-to $assignee --fields "System.Description=$description" "Microsoft.VSTS.Common.AcceptanceCriteria=$acceptanceCriteria" 'Microsoft.VSTS.Scheduling.StoryPoints=0' 'Microsoft.VSTS.Common.Priority=2' 'AAIT.Ready=Yes' 'AAIT.WorkType=4. Software / UX' 'System.State=Backlog' "System.Tags=$tags" "Microsoft.VSTS.Common.StackRank=$rankText" --output json > (Join-Path $outputDirectory 'created.json')
$createExitCode = $LASTEXITCODE
$createdText = Get-Content (Join-Path $outputDirectory 'created.json') -Raw
$created = $null
try { if ($createdText) { $created = $createdText | ConvertFrom-Json } } catch { $created = $null }
if ($createExitCode -ne 0 -or -not $created.id) {
    az boards query --organization $org --project $project --wiql $duplicateWiql --output json > (Join-Path $outputDirectory 'ambiguous_create_lookup.json')
    throw 'Creation ambiguous. Inspect exact-title recovery lookup; no automatic retry performed.'
}
$createdId = $created.id
Write-Host "CREATE id=$createdId title=$title"
az boards work-item relation add --id $createdId --organization $org --relation-type parent --target-id $parentId --output json > (Join-Path $outputDirectory 'linked.json')
if ($LASTEXITCODE -ne 0) { throw "Created $createdId but parent linking failed. Do not recreate." }
Write-Host "LINK child=$createdId parent=$parentId"
az boards work-item show --id $createdId --organization $org --expand relations --output json > (Join-Path $outputDirectory 'verified.json')
if ($LASTEXITCODE -ne 0) { throw "Final read failed for $createdId. Do not recreate." }
$verified = Get-Content (Join-Path $outputDirectory 'verified.json') -Raw | ConvertFrom-Json
$fields = $verified.fields
$parentRelations = @($verified.relations | Where-Object { $_.rel -eq 'System.LinkTypes.Hierarchy-Reverse' })
$actualTags = @($fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$checks = @(
    ($verified.id -eq $createdId),
    ($fields.'System.TeamProject' -eq $project),
    ($fields.'System.Title' -eq $title),
    ($fields.'System.WorkItemType' -eq 'User Story'),
    ($fields.'System.State' -eq 'Backlog'),
    ($fields.'System.AreaPath' -eq $area),
    ($fields.'System.IterationPath' -eq $iteration),
    ($fields.'System.AssignedTo'.uniqueName -eq $assignee),
    ($fields.'System.Description' -eq $description),
    ($fields.'Microsoft.VSTS.Common.AcceptanceCriteria' -eq $acceptanceCriteria),
    ($fields.'Microsoft.VSTS.Scheduling.StoryPoints' -eq 0),
    ($fields.'Microsoft.VSTS.Common.Priority' -eq 2),
    ($fields.'AAIT.Ready' -eq 'Yes'),
    ($fields.'AAIT.WorkType' -eq '4. Software / UX'),
    ([double]$fields.'Microsoft.VSTS.Common.StackRank' -eq $stackRank),
    ($parentRelations.Count -eq 1 -and $parentRelations[0].url.Split('/')[-1] -eq [string]$parentId),
    (@($expectedTags | Where-Object { $_ -notin $actualTags }).Count -eq 0)
)
if ($null -ne $priorMinimum) { $checks += ([double]$fields.'Microsoft.VSTS.Common.StackRank' -lt $priorMinimum) }
if ($checks -contains $false) { throw "Verification failed for $createdId; inspect verified.json. Do not recreate." }
Write-Host "VERIFY id=$createdId url=$org/$project/_workitems/edit/$createdId type=$($fields.'System.WorkItemType') state=$($fields.'System.State') assignee=$($fields.'System.AssignedTo'.displayName) area=$area iteration=$iteration tags=$($fields.'System.Tags') stackRank=$($fields.'Microsoft.VSTS.Common.StackRank') priorMin=$priorMinimum rankFallback=$rankFallback parent=$parentId description=verified acceptanceCriteria=verified"