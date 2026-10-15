$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"
$parentId = 2951224
$readinessId = 3148682
$iteration = "PassengerDataHub"

$readinessTitle = "PaxHub - Migration to MongoDB - PNR DEDUPE ASA - SCHEDULE CHANGE - PROD Readiness"
$deploymentTitle = "PaxHub - Migration to MongoDB - PNR DEDUPE ASA - SCHEDULE CHANGE - PROD Deployment"

$readinessDescription = '<div><b>Given</b> the Schedule Change Processor MongoDB migration has completed NONPROD filtering and validation activities<br><b>When</b> the team prepares the PAX production readiness package for the PNR DEDUPE ASA schedule change flow<br><b>Then</b> production readiness items, dependencies, approvals, and validation expectations are completed before release execution<br><b>And</b> engineering, QA, operations, and product stakeholders have the information needed to approve the production deployment</div><br><div><b>Context:</b> This story is based on the completed NONPROD schedule change filtering work item 3142364. The readiness work must validate that Schedule Change PNR filtering is production-ready for the MongoDB migration path, required configuration and release artifacts are prepared, operational checks are defined, and deployment risks are understood before production execution.</div>'

$readinessAcceptanceCriteria = '<div><b>Confirm production readiness for the schedule change migration flow</b><br><b>Given</b> the NONPROD implementation and validation for filtering Schedule Change PNRs is complete<br><b>When</b> the team reviews production readiness for the PNR DEDUPE ASA schedule change flow<br><b>Then</b> all required code, configuration, pipeline, access, dependency, and approval checks are documented and completed<br><b>And</b> open risks, release dependencies, and ownership for deployment activities are captured before production execution.</div><br><div><b>Validate release artifacts and configuration</b><br><b>Given</b> production release artifacts and environment configuration are prepared<br><b>When</b> the readiness review is performed<br><b>Then</b> artifact versions, configuration values, feature flags, secrets references, and deployment inputs are validated for production use<br><b>And</b> no hardcoded credentials or unapproved environment values are included in the release package.</div><br><div><b>Define rollback and failure handling expectations</b><br><b>Given</b> a production deployment may encounter validation failures, dependency issues, or unexpected upstream values<br><b>When</b> the team finalizes the readiness checklist<br><b>Then</b> rollback steps, mitigation options, owner actions, and escalation contacts are documented<br><b>And</b> the plan avoids exposing sensitive details while preserving enough information for incident response.</div><br><div><b>Update readiness documentation and stakeholder approvals</b><br><b>Given</b> the production readiness package is being finalized<br><b>When</b> documentation and approval evidence are reviewed<br><b>Then</b> release notes, validation evidence, monitoring expectations, and support notes are updated<br><b>And</b> engineering, QA, operations, and product stakeholders can access the approved readiness artifacts.</div><br><div><b>Assess consumer impact before release execution</b><br><b>Given</b> downstream PAX consumers depend on the migrated schedule change processing flow<br><b>When</b> the production readiness review is completed<br><b>Then</b> expected consumer-facing behavior and edge cases are documented before deployment<br><b>And</b> performance, reliability, monitoring, and data quality expectations are confirmed for production validation.</div>'

$deploymentDescription = '<div><b>Given</b> the PAX production readiness package for the PNR DEDUPE ASA schedule change flow has been approved<br><b>When</b> the team executes the production deployment for the Schedule Change Processor MongoDB migration path<br><b>Then</b> the production release is deployed using the approved pipeline or runbook steps<br><b>And</b> smoke validation, monitoring, rollback readiness, and stakeholder communications are completed during and after deployment</div><br><div><b>Context:</b> This story covers the production deployment execution that follows the PROD Readiness story. The deployment must activate the validated Schedule Change PNR filtering behavior in production, confirm the migrated MongoDB path behaves as expected, and verify that downstream PAX consumers are not disrupted.</div>'

$deploymentAcceptanceCriteria = '<div><b>Deploy the production release using the approved plan</b><br><b>Given</b> approved production artifacts and deployment instructions are available<br><b>When</b> the production deployment is executed for the Schedule Change Processor MongoDB migration path<br><b>Then</b> the release completes successfully using the approved pipeline or runbook steps<br><b>And</b> deployment timestamps, artifact versions, and operator actions are captured for auditability.</div><br><div><b>Validate production behavior after deployment</b><br><b>Given</b> the production deployment has completed<br><b>When</b> post-deployment smoke checks are executed<br><b>Then</b> Schedule Change PNR filtering is active in the production flow<br><b>And</b> validation confirms no unintended Schedule Change PNRs are processed through the migrated path.</div><br><div><b>Handle deployment failures and rollback conditions safely</b><br><b>Given</b> a production deployment failure, validation failure, or unexpected upstream value occurs<br><b>When</b> the deployment or post-deployment checks detect the issue<br><b>Then</b> the team follows the documented rollback or mitigation plan without causing system instability<br><b>And</b> clear error details, owner actions, and stakeholder communications are recorded for resolution.</div><br><div><b>Update deployment documentation and operational records</b><br><b>Given</b> the production release has been executed<br><b>When</b> deployment evidence and operational notes are finalized<br><b>Then</b> release notes, deployment records, validation evidence, and support references are updated<br><b>And</b> engineering, QA, operations, and product stakeholders can access the deployment outcome.</div><br><div><b>Monitor consumer impact and production health</b><br><b>Given</b> downstream PAX consumers depend on the migrated schedule change processing flow<br><b>When</b> production traffic is monitored after deployment<br><b>Then</b> consumer-facing behavior remains compatible with expected filtering outcomes<br><b>And</b> production monitoring, alerts, and logs provide sufficient visibility into reliability, performance, and data quality after deployment.</div>'

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

function Assert-NoDuplicateTitle {
    param(
        [string]$Title,
        [Nullable[int]]$AllowedId
    )
    $escapedTitle = $Title.Replace("'", "''")
    $wiql = "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.Title] = '$escapedTitle'"
    $items = az boards query --organization $org --project $project --wiql $wiql --output json | ConvertFrom-Json
    $duplicates = @($items | Where-Object { $null -eq $AllowedId -or $_.id -ne $AllowedId })
    if ($duplicates.Count -gt 0) {
        $duplicateId = $duplicates[0].id
        Write-Host "DUPLICATE duplicate_exists title=$Title id=$duplicateId url=$org/$project/_workitems/edit/$duplicateId"
        exit 10
    }
    Write-Host "DUPLICATE none title=$Title"
}

$parent = az boards work-item show --id $parentId --organization $org --expand all --output json | ConvertFrom-Json
if ($parent.fields.'System.TeamProject' -ne $project) { throw "Parent $parentId is not in project $project." }
if ($parent.fields.'System.WorkItemType' -ne "Feature") { throw "Parent $parentId is not a Feature." }

$area = $parent.fields.'System.AreaPath'
$parentTags = @($parent.fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$tags = @($parentTags + "AI-StoryWriting" | Sort-Object -Unique) -join "; "
Write-Host "PARENT id=$parentId type=$($parent.fields.'System.WorkItemType') area=$area tags=$tags"

$readiness = az boards work-item show --id $readinessId --organization $org --expand all --output json | ConvertFrom-Json
if ($readiness.fields.'System.WorkItemType' -ne "User Story") { throw "Readiness anchor $readinessId is not a User Story." }
if ((Get-ParentId -WorkItem $readiness) -ne $parentId) { throw "Readiness anchor $readinessId is not linked to parent $parentId." }

Assert-NoDuplicateTitle -Title $readinessTitle -AllowedId $readinessId
Assert-NoDuplicateTitle -Title $deploymentTitle -AllowedId $null

az boards work-item update `
    --id $readinessId `
    --organization $org `
    --fields "System.Title=$readinessTitle" `
             "System.Description=$readinessDescription" `
             "Microsoft.VSTS.Common.AcceptanceCriteria=$readinessAcceptanceCriteria" `
             "System.Tags=$tags" `
    --output json | Out-Null
Write-Host "UPDATE_READINESS id=$readinessId title=$readinessTitle"

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
    --title $deploymentTitle `
    --area $area `
    --iteration $iteration `
    --fields "System.Description=$deploymentDescription" `
             "Microsoft.VSTS.Common.AcceptanceCriteria=$deploymentAcceptanceCriteria" `
             "Microsoft.VSTS.Scheduling.StoryPoints=0" `
             "Microsoft.VSTS.Common.Priority=2" `
             "AAIT.Ready=Yes" `
             "AAIT.WorkType=4. Software / UX" `
             "System.State=Backlog" `
             "System.Tags=$tags" `
             "Microsoft.VSTS.Common.StackRank=$stackRank" `
    --output json | ConvertFrom-Json

$deploymentId = $created.id
if (-not $deploymentId) { throw "Create did not return a deployment work item ID." }
Write-Host "CREATE_DEPLOYMENT id=$deploymentId title=$deploymentTitle"

az boards work-item relation add --id $deploymentId --organization $org --relation-type parent --target-id $parentId --output json | Out-Null
Write-Host "LINK child=$deploymentId parent=$parentId"

$verifiedReadiness = az boards work-item show --id $readinessId --organization $org --expand all --output json | ConvertFrom-Json
$verifiedDeployment = az boards work-item show --id $deploymentId --organization $org --expand all --output json | ConvertFrom-Json

$readinessChecks = @(
    ($verifiedReadiness.fields.'System.Title' -eq $readinessTitle),
    ($verifiedReadiness.fields.'System.WorkItemType' -eq "User Story"),
    ($verifiedReadiness.fields.'System.State' -eq "Backlog"),
    ($verifiedReadiness.fields.'System.AreaPath' -eq $area),
    ($verifiedReadiness.fields.'System.IterationPath' -eq $iteration),
    ((Get-ParentId -WorkItem $verifiedReadiness) -eq $parentId)
)
$deploymentChecks = @(
    ($verifiedDeployment.fields.'System.Title' -eq $deploymentTitle),
    ($verifiedDeployment.fields.'System.WorkItemType' -eq "User Story"),
    ($verifiedDeployment.fields.'System.State' -eq "Backlog"),
    ($verifiedDeployment.fields.'System.AreaPath' -eq $area),
    ($verifiedDeployment.fields.'System.IterationPath' -eq $iteration),
    ((Get-ParentId -WorkItem $verifiedDeployment) -eq $parentId),
    ([double]$verifiedDeployment.fields.'Microsoft.VSTS.Common.StackRank' -eq [double]$stackRank)
)
if ($null -ne $priorMinRank) { $deploymentChecks += ([double]$verifiedDeployment.fields.'Microsoft.VSTS.Common.StackRank' -lt [double]$priorMinRank) }
if (($readinessChecks + $deploymentChecks) -contains $false) { throw "Verification failed for split stories." }

Write-Host "VERIFY_READINESS id=$readinessId url=$org/$project/_workitems/edit/$readinessId type=$($verifiedReadiness.fields.'System.WorkItemType') state=$($verifiedReadiness.fields.'System.State') area=$($verifiedReadiness.fields.'System.AreaPath') iteration=$($verifiedReadiness.fields.'System.IterationPath') tags=$($verifiedReadiness.fields.'System.Tags') stackRank=$($verifiedReadiness.fields.'Microsoft.VSTS.Common.StackRank') parent=$(Get-ParentId -WorkItem $verifiedReadiness)"
Write-Host "VERIFY_DEPLOYMENT id=$deploymentId url=$org/$project/_workitems/edit/$deploymentId type=$($verifiedDeployment.fields.'System.WorkItemType') state=$($verifiedDeployment.fields.'System.State') area=$($verifiedDeployment.fields.'System.AreaPath') iteration=$($verifiedDeployment.fields.'System.IterationPath') tags=$($verifiedDeployment.fields.'System.Tags') stackRank=$($verifiedDeployment.fields.'Microsoft.VSTS.Common.StackRank') parent=$(Get-ParentId -WorkItem $verifiedDeployment)"
Write-Host "VERIFY_READINESS_DESCRIPTION $($verifiedReadiness.fields.'System.Description')"
Write-Host "VERIFY_READINESS_ACCEPTANCE_CRITERIA $($verifiedReadiness.fields.'Microsoft.VSTS.Common.AcceptanceCriteria')"
Write-Host "VERIFY_DEPLOYMENT_DESCRIPTION $($verifiedDeployment.fields.'System.Description')"
Write-Host "VERIFY_DEPLOYMENT_ACCEPTANCE_CRITERIA $($verifiedDeployment.fields.'Microsoft.VSTS.Common.AcceptanceCriteria')"