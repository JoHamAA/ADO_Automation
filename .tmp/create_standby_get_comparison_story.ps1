$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"
$parentId = 3066956
$iteration = "PassengerDataHub"
$title = "PaxHub - Migration to MongoDB - Flight Standby Retrieval KPASS (GET) - Testing and Validation between MongoDB and SQLMI APIs"
$description = '<div><b>Given</b> the existing Flight Standby retrieval GET API reads from SQLMI and the KPASS GET API reads from MongoDB<br><b>When</b> equivalent requests are executed against both APIs using comparable data<br><b>Then</b> their status codes, response fields, values, and error or empty-result behavior are compared and differences recorded<br><b>And</b> each difference has an identified cause and any required correction is implemented and retested</div><br><div><b>Context:</b> Validate the MongoDB-backed KPASS Flight Standby retrieval GET API against the SQLMI-backed GET API before consumer migration. Story 3185341 implements MongoDB retrieval while preserving the existing response contract. Build a repeatable comparison across representative standby records and supported request parameters, account for source-data timing and intentional behavior changes, identify defects that affect parity, fix in-scope issues where required, and document unresolved differences and follow-up work. Do not require direct production PNR or passenger data in test artifacts.</div>'
$criteria = '<div><b>Compare equivalent standby GET responses</b><br><b>Given</b> the SQLMI and MongoDB APIs have comparable standby records and supported request parameters<br><b>When</b> the same GET requests are sent to both APIs<br><b>Then</b> HTTP status, response schema, fields, values, and ordering where contractually required are compared across representative cases<br><b>And</b> matching behavior or each observed difference is recorded with reproducible test inputs and sanitized outputs.</div><br><div><b>Explain discrepancies and correct required parity gaps</b><br><b>Given</b> a response differs between the SQLMI and MongoDB GET APIs<br><b>When</b> the team traces the source records, ingestion timing, mapping, filtering, and API logic<br><b>Then</b> the root cause is documented and intentional differences are distinguished from contract defects<br><b>And</b> an in-scope defect is corrected and retested on both APIs, or a tracked follow-up with owner and rationale is recorded.</div><br><div><b>Validate missing records and failure behavior</b><br><b>Given</b> requests may have invalid parameters, no matching standby data, delayed ingestion, or an unavailable data source<br><b>When</b> both GET APIs are exercised with those cases<br><b>Then</b> contract-defined empty, not-found, validation, and server-error behavior is compared without treating incomplete or fabricated data as a success<br><b>And</b> failures are logged and diagnosed without exposing passenger information.</div><br><div><b>Publish test evidence and consumer impact</b><br><b>Given</b> the comparison runs and discrepancy analysis are complete<br><b>When</b> the team prepares KPASS adoption guidance<br><b>Then</b> the test matrix, expected response contract, known differences, corrections, residual risks, and supporting evidence are documented<br><b>And</b> consumer compatibility and response-time or reliability impacts are assessed before SQLMI-based retrieval is replaced.</div>'

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