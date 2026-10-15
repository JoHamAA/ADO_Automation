$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"
$parentId = 2951224
$title = "PaxHub - Migration to MongoDB - PNR DEDUPE ASA - SCHEDULE CHANGE - PROD Readiness and Deployment"
$iteration = "PassengerDataHub"

$description = '<div><b>Given</b> the Schedule Change Processor MongoDB migration has completed NONPROD filtering and validation activities<br><b>When</b> the team prepares the PAX production release for the PNR DEDUPE ASA schedule change flow<br><b>Then</b> production readiness items are completed, deployment dependencies are confirmed, and the production release plan is approved for execution<br><b>And</b> the deployment can be performed with validation, monitoring, rollback, and stakeholder communication in place</div><br><div><b>Context:</b> This story is based on the completed NONPROD schedule change filtering work item 3142364. The production readiness and deployment work must validate that Schedule Change PNRs are filtered correctly for the MongoDB migration path, required configuration and release artifacts are ready, operational checks are defined, and the production deployment can be completed without disrupting downstream PAX consumers.</div>'

$acceptanceCriteria = '<div><b>Confirm production readiness for the schedule change migration flow</b><br><b>Given</b> the NONPROD implementation and validation for filtering Schedule Change PNRs is complete<br><b>When</b> the team reviews production readiness for the PNR DEDUPE ASA schedule change flow<br><b>Then</b> all required code, configuration, pipeline, access, dependency, and approval checks are documented and completed<br><b>And</b> open risks, release dependencies, and ownership for deployment activities are captured before production execution.</div><br><div><b>Deploy the production release using the approved plan</b><br><b>Given</b> approved production artifacts and deployment instructions are available<br><b>When</b> the production deployment is executed for the Schedule Change Processor MongoDB migration path<br><b>Then</b> the release completes successfully using the approved pipeline or runbook steps<br><b>And</b> post-deployment smoke validation confirms Schedule Change PNR filtering is active in the production flow.</div><br><div><b>Handle deployment failures and rollback conditions safely</b><br><b>Given</b> a production deployment failure, validation failure, or unexpected upstream value occurs<br><b>When</b> the deployment or post-deployment checks detect the issue<br><b>Then</b> the team follows the documented rollback or mitigation plan without causing system instability<br><b>And</b> clear error details, owner actions, and stakeholder communications are recorded for resolution.</div><br><div><b>Update release documentation and operational configuration</b><br><b>Given</b> production deployment readiness has been confirmed<br><b>When</b> the release package is finalized<br><b>Then</b> deployment documentation, configuration references, validation evidence, monitoring expectations, and support notes are updated<br><b>And</b> all relevant artifacts are accessible to engineering, QA, operations, and product stakeholders.</div><br><div><b>Validate consumer impact and production monitoring</b><br><b>Given</b> downstream PAX consumers depend on the migrated schedule change processing flow<br><b>When</b> the production release is completed<br><b>Then</b> consumer-facing behavior remains compatible with expected filtering outcomes and no unintended Schedule Change PNRs are processed through the migrated path<br><b>And</b> production monitoring, alerts, and logs provide sufficient visibility into reliability, performance, and data quality after deployment.</div>'

function Get-WorkItemIdFromUrl {
    param([string]$Url)
    return [int]($Url.Split('/')[-1])
}

function Get-ParentId {
    param($WorkItem)
    $parentRelation = @($WorkItem.relations | Where-Object { $_.rel -eq "System.LinkTypes.Hierarchy-Reverse" }) | Select-Object -First 1
    if (-not $parentRelation) { return $null }
    return Get-WorkItemIdFromUrl -Url $parentRelation.url
}

$parent = az boards work-item show --id $parentId --organization $org --expand all --output json | ConvertFrom-Json
if ($parent.fields.'System.TeamProject' -ne $project) { throw "Parent $parentId is not in project $project." }
if ($parent.fields.'System.WorkItemType' -ne "Feature") { throw "Parent $parentId is not a Feature." }

$area = $parent.fields.'System.AreaPath'
$parentTags = @($parent.fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$tags = @($parentTags + "AI-StoryWriting" | Sort-Object -Unique) -join "; "
Write-Host "PARENT id=$parentId type=$($parent.fields.'System.WorkItemType') area=$area tags=$tags"

$escapedTitle = $title.Replace("'", "''")
$duplicateWiql = "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.Title] = '$escapedTitle'"
$duplicates = az boards query --organization $org --project $project --wiql $duplicateWiql --output json | ConvertFrom-Json
if ($duplicates.Count -gt 0) {
    $duplicateId = $duplicates[0].id
    Write-Host "DUPLICATE duplicate_exists id=$duplicateId url=$org/$project/_workitems/edit/$duplicateId"
    exit 10
}
Write-Host "DUPLICATE none title=$title"

$rankWiql = "SELECT [System.Id], [Microsoft.VSTS.Common.StackRank] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.IterationPath] UNDER '$iteration' ORDER BY [Microsoft.VSTS.Common.StackRank] ASC"
$rankItems = az boards query --organization $org --project $project --wiql $rankWiql --output json | ConvertFrom-Json
$priorMinRank = $null
if ($rankItems.Count -gt 0) {
    $rankValue = $rankItems[0].fields.'Microsoft.VSTS.Common.StackRank'
    if ($null -ne $rankValue) { $priorMinRank = [double]$rankValue }
}
if ($null -eq $priorMinRank) {
    $stackRank = -1000000
    Write-Host "RANK priorMin=unavailable fallback=$stackRank"
} else {
    $stackRank = $priorMinRank - 1000
    Write-Host "RANK priorMin=$priorMinRank new=$stackRank"
}

$created = az boards work-item create `
    --organization $org `
    --project $project `
    --type "User Story" `
    --title $title `
    --area $area `
    --iteration $iteration `
    --fields "System.Description=$description" `
             "Microsoft.VSTS.Common.AcceptanceCriteria=$acceptanceCriteria" `
             "Microsoft.VSTS.Scheduling.StoryPoints=0" `
             "Microsoft.VSTS.Common.Priority=2" `
             "AAIT.Ready=Yes" `
             "AAIT.WorkType=4. Software / UX" `
             "System.State=Backlog" `
             "System.Tags=$tags" `
             "Microsoft.VSTS.Common.StackRank=$stackRank" `
    --output json | ConvertFrom-Json

$createdId = $created.id
if (-not $createdId) { throw "Create did not return a work item ID." }
Write-Host "CREATE id=$createdId title=$title"

az boards work-item relation add --id $createdId --organization $org --relation-type parent --target-id $parentId --output json | Out-Null
Write-Host "LINK child=$createdId parent=$parentId"

$verified = az boards work-item show --id $createdId --organization $org --expand all --output json | ConvertFrom-Json
$verifiedParentId = Get-ParentId -WorkItem $verified
$verifiedRank = $verified.fields.'Microsoft.VSTS.Common.StackRank'
$verifiedDescription = $verified.fields.'System.Description'
$verifiedAcceptanceCriteria = $verified.fields.'Microsoft.VSTS.Common.AcceptanceCriteria'

$checks = @(
    ($verified.id -eq $createdId),
    ($verified.fields.'System.Title' -eq $title),
    ($verified.fields.'System.WorkItemType' -eq "User Story"),
    ($verified.fields.'System.State' -eq "Backlog"),
    ($verified.fields.'System.AreaPath' -eq $area),
    ($verified.fields.'System.IterationPath' -eq $iteration),
    ($verifiedParentId -eq $parentId),
    ([double]$verifiedRank -eq [double]$stackRank)
)
if ($null -ne $priorMinRank) { $checks += ([double]$verifiedRank -lt [double]$priorMinRank) }
if ($checks -contains $false) { throw "Verification failed for created work item $createdId." }

Write-Host "VERIFY id=$createdId url=$org/$project/_workitems/edit/$createdId type=$($verified.fields.'System.WorkItemType') state=$($verified.fields.'System.State') area=$($verified.fields.'System.AreaPath') iteration=$($verified.fields.'System.IterationPath') tags=$($verified.fields.'System.Tags') stackRank=$verifiedRank parent=$verifiedParentId"
Write-Host "VERIFY_DESCRIPTION $verifiedDescription"
Write-Host "VERIFY_ACCEPTANCE_CRITERIA $verifiedAcceptanceCriteria"