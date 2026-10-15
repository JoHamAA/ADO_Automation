param([switch]$Execute, [switch]$Resume)

$ErrorActionPreference = 'Stop'
$org = 'https://dev.azure.com/AmericanAirlines'
$project = 'PassengerDataHub'
$parentId = 3107210
$iteration = 'PassengerDataHub'
$elements = @('AddressHistory', 'NameHistory', 'FrequentFlierHistory', 'RemarkHistory', 'TicketingHistory', 'SeatsHistory', 'FactHistory', 'AncillaryServicesHistory', 'PassengerDetailsHistory', 'PhoneHistory')
$outputDirectory = Join-Path $env:TEMP 'pax_history_3107210'
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

function Invoke-AdoJson {
    param([string[]]$Arguments, [string]$Name)
    $outputPath = Join-Path $outputDirectory "$Name.json"
    & az @Arguments --output json > $outputPath
    if ($LASTEXITCODE -ne 0) { throw "Azure DevOps command failed: $Name. No automatic retry performed." }
    $content = Get-Content $outputPath -Raw
    if ([string]::IsNullOrWhiteSpace($content)) {
        if ($Arguments[0] -eq 'boards' -and $Arguments[1] -eq 'query') { return @() }
        throw "Azure DevOps returned no output: $Name. No automatic retry performed."
    }
    return ($content | ConvertFrom-Json)
}

function Get-StoryContent {
    param([string]$Element)
    return @{
        Title = "PaxHub - Migration to MongoDB - PNR GRAPH API - Enhance History Response to include $Element (NONPROD)"
        Description = "<div><b>Given</b> PNR Graph API retrieves MongoDB booking history from the bkg_hist collection<br><b>When</b> an authorized consumer requests the history portion of a PNR including $Element<br><b>Then</b> the API retrieves and exposes all applicable $Element entries in the history response<br><b>And</b> the corresponding GraphQL schema is updated and published in dev, test, and stage environments</div><br><div><b>Context:</b> Enhance the PNR Graph API response to expose the entire history portion of the PNR. This story focuses exclusively on $Element sourced from the MongoDB bkg_hist collection. Confirm the source document structure and map the applicable fields and historical entries into the history response without omitting valid entries. Update and publish the schema and API documentation in dev, test, and stage. Scope is NONPROD only; production deployment and other history components are outside this story.</div>"
        AcceptanceCriteria = "<div><b>Expose complete $Element in the PNR history response</b><br><b>Given</b> bkg_hist contains valid $Element entries for the requested PNR across multiple history transactions<br><b>When</b> an authorized consumer requests $Element through PNR Graph API<br><b>Then</b> the response includes every applicable entry with values correctly mapped from bkg_hist<br><b>And</b> automated tests confirm completeness, the documented ordering, and that entries from other PNRs are not included.</div><br><div><b>Handle missing or invalid $Element and retrieval failures safely</b><br><b>Given</b> $Element is absent, empty, null, contains malformed values, or MongoDB retrieval fails<br><b>When</b> PNR Graph API resolves the requested history<br><b>Then</b> absent data follows the documented empty or null contract and invalid data or retrieval failures follow the documented GraphQL error contract without system instability<br><b>And</b> valid unaffected response fields are preserved where the schema permits and diagnostics do not expose sensitive PNR data.</div><br><div><b>Publish the $Element schema in dev, test, and stage</b><br><b>Given</b> the $Element source mapping and response contract are validated<br><b>When</b> the GraphQL schema and API documentation are updated and published<br><b>Then</b> dev, test, and stage expose the agreed fields, types, nullability, ordering, and empty-data behavior<br><b>And</b> schema validation and environment smoke tests confirm consumers can query $Element successfully in all three environments.</div><br><div><b>Verify consumer compatibility and secure $Element retrieval</b><br><b>Given</b> existing consumers query PNR Graph API and representative PNRs include large history volumes<br><b>When</b> regression and performance tests run in NONPROD with and without $Element selected<br><b>Then</b> existing response fields remain compatible and response time and error rate are compared with the baseline against agreed API performance limits<br><b>And</b> consumer impact is documented, existing PNR authorization is enforced, and sensitive history values are not exposed in logs.</div>"
    }
}

function Get-Duplicates {
    param([string]$Title, [string]$Name)
    $escapedTitle = $Title.Replace("'", "''")
    $wiql = "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.IterationPath] UNDER '$iteration' AND [System.WorkItemType] = 'User Story' AND [System.Title] = '$escapedTitle'"
    return (Invoke-AdoJson -Arguments @('boards', 'query', '--organization', $org, '--project', $project, '--wiql', $wiql) -Name $Name)
}

function Get-MinimumRank {
    param([string]$Name)
    $wiql = "SELECT [System.Id], [Microsoft.VSTS.Common.StackRank] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.AreaPath] UNDER '$area' AND [System.IterationPath] UNDER '$iteration' AND [System.WorkItemType] = 'User Story' ORDER BY [Microsoft.VSTS.Common.StackRank] ASC"
    $items = Invoke-AdoJson -Arguments @('boards', 'query', '--organization', $org, '--project', $project, '--wiql', $wiql) -Name $Name
    $ranks = @($items | ForEach-Object {
        $candidate = $_.fields.'Microsoft.VSTS.Common.StackRank'
        $numericRank = 0.0
        if ($null -ne $candidate -and [double]::TryParse([string]$candidate, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$numericRank) -and -not [double]::IsNaN($numericRank) -and -not [double]::IsInfinity($numericRank)) {
            $numericRank
        }
    })
    if ($ranks.Count -eq 0) { return $null }
    return ($ranks | Measure-Object -Minimum).Minimum
}

$parent = Invoke-AdoJson -Arguments @('boards', 'work-item', 'show', '--id', "$parentId", '--organization', $org, '--expand', 'relations') -Name 'parent'
if ($parent.id -ne $parentId -or $parent.fields.'System.TeamProject' -ne $project -or $parent.fields.'System.WorkItemType' -ne 'Feature') { throw 'Parent must be a Feature in PassengerDataHub.' }
$area = $parent.fields.'System.AreaPath'
$parentTags = @($parent.fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$expectedTags = @($parentTags + 'AI-StoryWriting' | Select-Object -Unique)
$tags = $expectedTags -join '; '
Write-Host "PARENT id=$parentId title=$($parent.fields.'System.Title') area=$area tags=$tags"
$iterationNodes = Invoke-AdoJson -Arguments @('boards', 'iteration', 'project', 'list', '--organization', $org, '--project', $project, '--depth', '0') -Name 'iteration'
if (-not (@($iterationNodes | Where-Object { $_.name -eq $iteration }) ).Count) { throw 'Shared PassengerDataHub backlog iteration could not be validated.' }

foreach ($element in $elements) {
    $story = Get-StoryContent -Element $element
    $duplicates = @(Get-Duplicates -Title $story.Title -Name "preflight_duplicate_$element")
    if ($duplicates.Count -gt 0) {
        $savedCreation = Join-Path $outputDirectory "created_$element.json"
        if ($Resume -and $duplicates.Count -eq 1 -and (Test-Path $savedCreation)) {
            $previous = Get-Content $savedCreation -Raw | ConvertFrom-Json
            if ($previous.id -eq $duplicates[0].id -and $previous.fields.'System.Title' -ceq $story.Title) {
                Write-Host "DUPLICATE resume_existing id=$($previous.id) title=$($story.Title)"
                continue
            }
        }
        foreach ($duplicate in $duplicates) { Write-Host "DUPLICATE duplicate_exists id=$($duplicate.id) url=$org/$project/_workitems/edit/$($duplicate.id) title=$($story.Title)" }
        throw 'Duplicate exists; batch stopped before writes.'
    }
    if ([regex]::Matches($story.AcceptanceCriteria, '<b>Given</b>').Count -ne 4 -or $story.AcceptanceCriteria -match 'Scenario:|Scenario [0-9]|Happy Path|Negative Path') { throw "Invalid acceptance criteria for $element" }
    Write-Host "DUPLICATE none title=$($story.Title)"
}
$preflightMinimum = Get-MinimumRank -Name 'preflight_rank'
Write-Host "RANK preflightMinimum=$preflightMinimum fallback=-1000000000000"
if (-not $Execute) {
    Write-Host "PREFLIGHT read_only stories=$($elements.Count) state=Backlog area=$area iteration=$iteration points=0 priority=2 ready=Yes workType=4.Software/UX"
    exit 0
}

foreach ($element in $elements) {
    $story = Get-StoryContent -Element $element
    $savedCreation = Join-Path $outputDirectory "created_$element.json"
    if ($Resume -and (Test-Path $savedCreation)) {
        $created = Get-Content $savedCreation -Raw | ConvertFrom-Json
        if (-not $created.id -or $created.fields.'System.Title' -cne $story.Title) { throw 'Invalid saved creation record.' }
        $rank = [double]$created.fields.'Microsoft.VSTS.Common.StackRank'
        $originalRanks = Get-Content (Join-Path $outputDirectory "rank_$element.json") -Raw | ConvertFrom-Json
        $priorMinimum = ($originalRanks | ForEach-Object { $_.fields.'Microsoft.VSTS.Common.StackRank' } | Where-Object { $null -ne $_ } | Measure-Object -Minimum).Minimum
        $fallback = $null -eq $priorMinimum
        Write-Host "CREATE resume_existing id=$($created.id) title=$($story.Title)"
    } else {
    $priorMinimum = Get-MinimumRank -Name "rank_$element"
    $rank = -1000000000000.0
    $fallback = $null -eq $priorMinimum
    if (-not $fallback) { $rank = [Math]::Floor($priorMinimum - [Math]::Max(1000.0, [Math]::Abs($priorMinimum) * 0.01)) }
    $rankText = $rank.ToString('R', [System.Globalization.CultureInfo]::InvariantCulture)
    Write-Host "RANK element=$element priorMinimum=$priorMinimum assigned=$rankText fallback=$fallback"
    $duplicates = @(Get-Duplicates -Title $story.Title -Name "duplicate_$element")
    if ($duplicates.Count -gt 0) { throw "DUPLICATE duplicate_exists id=$($duplicates[0].id) url=$org/$project/_workitems/edit/$($duplicates[0].id)" }
    Write-Host "DUPLICATE none title=$($story.Title)"
    $arguments = @('boards', 'work-item', 'create', '--organization', $org, '--project', $project, '--type', 'User Story', '--title', $story.Title, '--area', $area, '--iteration', $iteration, '--fields',
        "System.Description=$($story.Description)", "Microsoft.VSTS.Common.AcceptanceCriteria=$($story.AcceptanceCriteria)",
        'Microsoft.VSTS.Scheduling.StoryPoints=0', 'Microsoft.VSTS.Common.Priority=2', 'AAIT.Ready=Yes', 'AAIT.WorkType=4. Software / UX',
        'System.State=Backlog', "System.Tags=$tags", "Microsoft.VSTS.Common.StackRank=$rankText")
    try {
        $created = Invoke-AdoJson -Arguments $arguments -Name "created_$element"
        if (-not $created.id) { throw 'Create response missing ID.' }
    } catch {
        $creationError = $_
        $matches = @(Get-Duplicates -Title $story.Title -Name "ambiguous_create_$element")
        foreach ($match in $matches) { Write-Host "CREATE ambiguous id=$($match.id) url=$org/$project/_workitems/edit/$($match.id)" }
        throw $creationError
    }
    Write-Host "CREATE id=$($created.id) title=$($story.Title)"
    $null = Invoke-AdoJson -Arguments @('boards', 'work-item', 'relation', 'add', '--id', "$($created.id)", '--organization', $org, '--relation-type', 'parent', '--target-id', "$parentId") -Name "linked_$element"
    Write-Host "LINK child=$($created.id) parent=$parentId"
    }
    $verified = Invoke-AdoJson -Arguments @('boards', 'work-item', 'show', '--id', "$($created.id)", '--organization', $org, '--expand', 'relations') -Name "verified_$element"
    $fields = $verified.fields
    $actualTags = @($fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $parents = @($verified.relations | Where-Object { $_.rel -eq 'System.LinkTypes.Hierarchy-Reverse' })
    $checks = @(
        ($verified.id -eq $created.id), ($fields.'System.Title' -ceq $story.Title),
        ($fields.'System.WorkItemType' -eq 'User Story'), ($fields.'System.State' -eq 'Backlog'),
        ($fields.'System.AreaPath' -eq $area), ($fields.'System.IterationPath' -eq $iteration),
        (@(Compare-Object $expectedTags $actualTags -CaseSensitive).Count -eq 0),
        ($parents.Count -eq 1 -and $parents[0].url.Split('/')[-1] -eq "$parentId"),
        ([Math]::Abs([double]$fields.'Microsoft.VSTS.Common.StackRank' - $rank) -le [Math]::Max(0.000001, [Math]::Abs($rank) * 0.000000000001)),
        (($fields.'System.Description' -replace '\s+(?=</div>)', '') -ceq ($story.Description -replace '\s+(?=</div>)', '')),
        (($fields.'Microsoft.VSTS.Common.AcceptanceCriteria' -replace '\s+(?=</div>)', '') -ceq ($story.AcceptanceCriteria -replace '\s+(?=</div>)', '')),
        ($fields.'Microsoft.VSTS.Scheduling.StoryPoints' -eq 0), ($fields.'Microsoft.VSTS.Common.Priority' -eq 2),
        ($fields.'AAIT.Ready' -eq 'Yes'), ($fields.'AAIT.WorkType' -eq '4. Software / UX')
    )
    if (-not $fallback) { $checks += ([double]$fields.'Microsoft.VSTS.Common.StackRank' -lt $priorMinimum) }
    if ($checks -contains $false) { throw "VERIFY failed for id=$($created.id). Inspect $outputDirectory; do not recreate." }
    Write-Host "VERIFY id=$($created.id) url=$org/$project/_workitems/edit/$($created.id) title=$($fields.'System.Title') type=User Story state=Backlog area=$area iteration=$iteration tags=$($fields.'System.Tags') stackRank=$($fields.'Microsoft.VSTS.Common.StackRank') parent=$parentId fallback=$fallback"
    Write-Host "VERIFY_DESCRIPTION $($fields.'System.Description')"
    Write-Host "VERIFY_ACCEPTANCE_CRITERIA $($fields.'Microsoft.VSTS.Common.AcceptanceCriteria')"
}