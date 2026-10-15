$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"
$parentId = 2951225
$sourceStoryId = 3058096
$title = "PaxHub - Migration to MongoDB - ENCRYPTION - Define Schema for bkg_cust_doc Collection (PROD)"
$iteration = "PassengerDataHub"

$description = '<div><b>Given</b> the approved NONPROD bkg_cust_doc schema defines the structure and encryption requirements for government document information<br><b>When</b> the Mongo SPII persistence flow is prepared for production<br><b>Then</b> the bkg_cust_doc collection schema and validation configuration are implemented for PROD using the approved design<br><b>And</b> encrypted government document records can be stored, validated, and retrieved through authorized production paths</div><br><div><b>Context:</b> This story is the PROD counterpart to work item 3058096. The production collection must preserve the approved PNR-level attributes, document array structure, document-level attributes, validation rules, and encryption treatment for govDocId. Environment-specific schema configuration, indexes, access controls, deployment evidence, monitoring, and rollback instructions must be completed without exposing sensitive government document values.</div>'

$acceptanceCriteria = '<div><b>Implement the approved bkg_cust_doc schema in PROD</b><br><b>Given</b> the NONPROD schema from work item 3058096 has been reviewed and approved<br><b>When</b> the bkg_cust_doc collection is configured in the production MongoDB environment<br><b>Then</b> required PNR-level fields, the documents array, document-level fields, validation rules, and approved indexes are implemented consistently<br><b>And</b> govDocId and all other designated sensitive fields use the approved encryption configuration before persistence.</div><br><div><b>Reject invalid documents and handle encryption failures safely</b><br><b>Given</b> production messages may contain missing, malformed, duplicate, or unexpected government document values<br><b>When</b> a record violates the collection schema or encryption cannot be completed<br><b>Then</b> the record is rejected or handled through the approved recovery path without corrupting valid production data<br><b>And</b> actionable errors and monitoring signals are produced without logging sensitive document values.</div><br><div><b>Validate production persistence and authorized retrieval</b><br><b>Given</b> the PROD schema, encryption settings, access controls, and indexes are deployed<br><b>When</b> representative single-document and multi-document PNR records are processed<br><b>Then</b> records are stored in the expected bkg_cust_doc structure and encrypted fields are not readable at rest<br><b>And</b> authorized consumers can retrieve required values while unauthorized identities are denied.</div><br><div><b>Complete production documentation and operational readiness</b><br><b>Given</b> the production collection must be supportable and recoverable<br><b>When</b> schema implementation is completed<br><b>Then</b> the schema definition, validators, indexes, encryption references, access ownership, deployment steps, monitoring, and rollback procedure are documented<br><b>And</b> performance, capacity, reliability, security, and downstream consumer impacts are assessed with production validation evidence recorded.</div>'

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

$parent = az boards work-item show --id $parentId --organization $org --expand all --output json | ConvertFrom-Json
if ($parent.fields.'System.TeamProject' -ne $project) { throw "PARENT $parentId is not in $project." }
if ($parent.fields.'System.WorkItemType' -ne "Feature") { throw "PARENT $parentId is not a Feature." }

$area = $parent.fields.'System.AreaPath'
$parentTags = @($parent.fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$tags = @($parentTags + "AI-StoryWriting" | Sort-Object -Unique) -join "; "
Write-Host "PARENT id=$parentId type=Feature area=$area iteration=$iteration tags=$tags source=$sourceStoryId"

$escapedTitle = $title.Replace("'", "''")
$duplicateWiql = "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.Title] = '$escapedTitle'"
$duplicates = @(az boards query --organization $org --project $project --wiql $duplicateWiql --output json | ConvertFrom-Json)
if ($duplicates.Count -gt 0) {
    $duplicateId = $duplicates[0].id
    Write-Host "DUPLICATE duplicate_exists id=$duplicateId url=$org/$project/_workitems/edit/$duplicateId"
    exit 10
}
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
if (-not $created.id) { throw "CREATE failed for $title." }
$createdId = [int]$created.id
Write-Host "CREATE id=$createdId rank=$stackRank title=$title"

az boards work-item relation add --id $createdId --organization $org --relation-type parent --target-id $parentId --output json | Out-Null
Write-Host "LINK child=$createdId parent=$parentId"

$verified = az boards work-item show --id $createdId --organization $org --expand all --output json | ConvertFrom-Json
$verifiedParentId = Get-ParentId -WorkItem $verified
$verifiedTags = @($verified.fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
$expectedTags = @($tags -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
$checks = @(
    ($verified.id -eq $createdId),
    ($verified.fields.'System.Title' -eq $title),
    ($verified.fields.'System.WorkItemType' -eq "User Story"),
    ($verified.fields.'System.State' -eq "Backlog"),
    ($verified.fields.'System.AreaPath' -eq $area),
    ($verified.fields.'System.IterationPath' -eq $iteration),
    ($null -eq (Compare-Object $expectedTags $verifiedTags)),
    ($verifiedParentId -eq $parentId),
    ((Normalize-RichText $verified.fields.'System.Description') -eq (Normalize-RichText $description)),
    ((Normalize-RichText $verified.fields.'Microsoft.VSTS.Common.AcceptanceCriteria') -eq (Normalize-RichText $acceptanceCriteria)),
    ([double]$verified.fields.'Microsoft.VSTS.Common.StackRank' -eq [double]$stackRank)
)
if ($null -ne $priorMinRank) {
    $checks += ([double]$verified.fields.'Microsoft.VSTS.Common.StackRank' -lt $priorMinRank)
}
if ($checks -contains $false) { throw "VERIFY failed for work item $createdId." }

Write-Host "VERIFY id=$createdId url=$org/$project/_workitems/edit/$createdId title=$($verified.fields.'System.Title') type=$($verified.fields.'System.WorkItemType') state=$($verified.fields.'System.State') area=$($verified.fields.'System.AreaPath') iteration=$($verified.fields.'System.IterationPath') tags=$($verified.fields.'System.Tags') stackRank=$($verified.fields.'Microsoft.VSTS.Common.StackRank') parent=$verifiedParentId description=true acceptanceCriteria=true"