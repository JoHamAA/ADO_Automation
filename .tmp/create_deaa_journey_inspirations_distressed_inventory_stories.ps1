$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "DataEngineering"
$parentId = 3150151

$stories = @(
    @{
        Title = "Journey Inspirations - Distressed Inventory - Source Table Discovery and Access Readiness"
        Description = '<div><b>Given</b> the Journey Inspirations distressed inventory initiative is beginning and the source table details are pending from Jeremy<br><b>When</b> source table details and environment access needs are gathered for Non-Prod and Prod<br><b>Then</b> the team has the source table name, owning system, data availability expectations, access requirements, and contacts needed to begin analysis<br><b>And</b> open questions and dependencies are documented before profiling and design begin</div><br><div><b>Context:</b> This is the first discovery story for Journey Inspirations, formerly Tailored Destinations, focused on the distressed inventory feature. Jeremy is expected to provide source table details. The team needs Non-Prod and Prod access clarity before downstream gold layer, pipeline, and Event Hub work can proceed.</div>'
        AcceptanceCriteria = '<div><b>Capture source table details and ownership</b><br><b>Given</b> Jeremy provides the source table information for distressed inventory<br><b>When</b> the team documents the source table details<br><b>Then</b> table name, source system, owner, refresh cadence, expected volume, key fields, and contact information are captured<br><b>And</b> missing details are tracked with owners and due dates.</div><br><div><b>Confirm Non-Prod and Prod access requirements</b><br><b>Given</b> the source table will be used for development and production data processing<br><b>When</b> access requirements are reviewed<br><b>Then</b> required Non-Prod and Prod roles, groups, approvals, and request paths are identified<br><b>And</b> access constraints or data handling restrictions are documented.</div><br><div><b>Handle missing or incomplete source information</b><br><b>Given</b> source metadata or access details may be incomplete at project start<br><b>When</b> required details are unavailable<br><b>Then</b> the team records the gap, identifies the responsible contact, and blocks dependent work until the detail is resolved<br><b>And</b> no assumptions are promoted into development without review.</div><br><div><b>Document discovery findings for review</b><br><b>Given</b> source table and access information has been gathered<br><b>When</b> the discovery package is finalized<br><b>Then</b> findings are documented in the approved project location<br><b>And</b> the documentation is available to engineering, product, and platform stakeholders.</div><br><div><b>Assess security and data handling impact</b><br><b>Given</b> source table access may include customer or inventory-related data<br><b>When</b> access needs are reviewed<br><b>Then</b> data sensitivity, least-privilege access, and retention expectations are assessed<br><b>And</b> any compliance or approval dependencies are recorded before profiling begins.</div>'
    }
    @{
        Title = "Journey Inspirations - Distressed Inventory - Source Table Access Validation and Data Profiling"
        Description = '<div><b>Given</b> source table details and access requirements have been gathered<br><b>When</b> the team validates table access and profiles the source data<br><b>Then</b> the team understands the available records, field population, data quality, keys, and transformation considerations<br><b>And</b> profiling findings are ready to inform the gold layer table design</div><br><div><b>Context:</b> This story validates practical access to the source table and performs data profiling for the Journey Inspirations distressed inventory use case. The profiling output should inform schema, partitioning, quality rules, event payload content, and downstream expectations.</div>'
        AcceptanceCriteria = '<div><b>Verify source table access in available environments</b><br><b>Given</b> access has been requested for the distressed inventory source table<br><b>When</b> the team attempts to query the source in approved environments<br><b>Then</b> access succeeds for authorized users or service identities<br><b>And</b> any missing permissions are documented with remediation owners.</div><br><div><b>Profile source data quality and structure</b><br><b>Given</b> the source table is queryable<br><b>When</b> profiling queries are executed<br><b>Then</b> row counts, distinct customer or inventory keys, null rates, duplicates, data ranges, and field formats are captured<br><b>And</b> findings identify fields needed for the gold table and event payload.</div><br><div><b>Handle unexpected source data conditions</b><br><b>Given</b> the source data may include missing keys, duplicate records, malformed values, or unexpected volumes<br><b>When</b> profiling detects data quality concerns<br><b>Then</b> the concerns are documented with example records and expected handling recommendations<br><b>And</b> no destructive source changes are performed during profiling.</div><br><div><b>Publish profiling output for schema review</b><br><b>Given</b> profiling has been completed<br><b>When</b> the output is prepared for review<br><b>Then</b> profiling queries, metrics, assumptions, and known limitations are documented<br><b>And</b> the information is accessible for gold layer schema design.</div><br><div><b>Assess performance and access impact</b><br><b>Given</b> profiling queries run against shared data platforms<br><b>When</b> profiling is performed<br><b>Then</b> queries use appropriate filters, sampling, and execution windows to avoid unnecessary load<br><b>And</b> any production profiling restrictions are captured before Prod access is used.</div>'
    }
    @{
        Title = "Journey Inspirations - Distressed Inventory - Gold Layer Table Schema Design and Review"
        Description = '<div><b>Given</b> source table profiling has identified the fields and data quality patterns for distressed inventory<br><b>When</b> the team designs the final North Star gold layer table<br><b>Then</b> the schema, keys, partitioning, refresh expectations, and quality rules are reviewed and approved before development begins<br><b>And</b> the agreed design can be used by ingestion and Event Hub streaming development</div><br><div><b>Context:</b> This story converts source table understanding into the final gold layer table design for Journey Inspirations distressed inventory. Actual development should begin only after this schema is finalized and reviewed.</div>'
        AcceptanceCriteria = '<div><b>Define the gold layer table schema</b><br><b>Given</b> profiling findings are available<br><b>When</b> the gold table design is drafted<br><b>Then</b> column names, data types, keys, nullable fields, partitioning, refresh cadence, and table ownership are defined<br><b>And</b> the schema supports the downstream per-customer Event Hub payload needs.</div><br><div><b>Review and approve the schema before development</b><br><b>Given</b> a draft gold layer table design exists<br><b>When</b> engineering and product stakeholders review the design<br><b>Then</b> feedback is captured and resolved before implementation begins<br><b>And</b> the final schema is explicitly approved for development.</div><br><div><b>Handle schema gaps and source ambiguity</b><br><b>Given</b> source fields or business rules may be ambiguous<br><b>When</b> schema questions remain unresolved<br><b>Then</b> the team documents the decision needed, owner, and impact on development<br><b>And</b> dependent implementation work waits for approved resolution.</div><br><div><b>Document schema and data contract expectations</b><br><b>Given</b> the gold layer schema is approved<br><b>When</b> design documentation is finalized<br><b>Then</b> schema details, transformation rules, quality checks, and consumer expectations are documented<br><b>And</b> the documentation is ready to support notebook, task, pipeline, and contract development.</div><br><div><b>Assess downstream consumer and retention impact</b><br><b>Given</b> the gold table will feed per-customer events<br><b>When</b> the schema is reviewed<br><b>Then</b> downstream payload needs, data retention expectations, and edge cases are assessed<br><b>And</b> known consumer impacts are recorded before build begins.</div>'
    }
    @{
        Title = "Journey Inspirations - Distressed Inventory - Event Hub Infrastructure and Payload Design"
        Description = '<div><b>Given</b> the gold layer table design is being finalized for distressed inventory<br><b>When</b> the team designs Event Hub publishing requirements and works with the platform team<br><b>Then</b> the Event Hub namespace, topic, retention, access model, and payload JSON content are defined<br><b>And</b> infrastructure dependencies are ready to support the write stream job</div><br><div><b>Context:</b> This story covers Event Hub infrastructure setup and design decisions for the downstream team that will consume per-customer distressed inventory events. The payload JSON and retention settings must be finalized based on how downstream consumers plan to read the Event Hub.</div>'
        AcceptanceCriteria = '<div><b>Define Event Hub payload content</b><br><b>Given</b> downstream consumers need per-customer distressed inventory events<br><b>When</b> the payload design is reviewed<br><b>Then</b> required JSON fields, keys, event metadata, timestamps, nullable behavior, and sample payloads are defined<br><b>And</b> the payload aligns with the approved gold layer schema.</div><br><div><b>Finalize Event Hub retention and consumption expectations</b><br><b>Given</b> downstream teams will read events from Event Hub<br><b>When</b> consumer access patterns are confirmed<br><b>Then</b> retention, partitioning, throughput, replay expectations, and consumer group needs are documented<br><b>And</b> unresolved downstream questions are tracked before stream development begins.</div><br><div><b>Coordinate namespace and topic creation with platform team</b><br><b>Given</b> Event Hub infrastructure is required for the write stream job<br><b>When</b> platform setup is requested<br><b>Then</b> namespace, topic, access policies, networking, and environment-specific resources are created or tracked through completion<br><b>And</b> infrastructure identifiers are documented for development configuration.</div><br><div><b>Handle infrastructure and access failures</b><br><b>Given</b> Event Hub provisioning or permissions may fail<br><b>When</b> setup validation detects missing resources or access issues<br><b>Then</b> clear errors, remediation owners, and target dates are captured<br><b>And</b> development does not hardcode temporary endpoints or credentials.</div><br><div><b>Document operational and security requirements</b><br><b>Given</b> Event Hub will carry per-customer event data<br><b>When</b> infrastructure design is finalized<br><b>Then</b> monitoring, access control, retention, encryption, and operational ownership expectations are documented<br><b>And</b> the setup follows least-privilege and approved platform standards.</div>'
    }
    @{
        Title = "Journey Inspirations - Distressed Inventory - North Star Gold Table Load Development"
        Description = '<div><b>Given</b> the final gold layer schema and source table details are approved<br><b>When</b> the team develops the notebook, task, and pipeline for North Star ingestion<br><b>Then</b> the gold table is loaded from the source table provided by Jeremy into North Star<br><b>And</b> the load includes validation, logging, configuration, and recoverability appropriate for Dev execution</div><br><div><b>Context:</b> This story starts implementation after schema approval. It focuses on the notebook, task, and pipeline steps needed to load the Journey Inspirations distressed inventory gold table into North Star from the approved source table.</div>'
        AcceptanceCriteria = '<div><b>Develop the gold table load notebook and task</b><br><b>Given</b> the approved source table and gold schema are available<br><b>When</b> the ingestion notebook and task are implemented<br><b>Then</b> data is read from the source table and written into the North Star gold table using approved transformations<br><b>And</b> the implementation follows project standards for configuration, naming, and execution.</div><br><div><b>Build the pipeline orchestration for Dev execution</b><br><b>Given</b> the notebook and task are ready<br><b>When</b> the pipeline is configured<br><b>Then</b> the gold table load can be triggered in Dev with the correct dependencies and parameters<br><b>And</b> pipeline status clearly reports success, failure, and retry conditions.</div><br><div><b>Handle invalid source data and load failures</b><br><b>Given</b> source data may contain missing, malformed, duplicate, or unexpected values<br><b>When</b> the load encounters invalid records or execution failures<br><b>Then</b> errors are logged with actionable context and bad data handling follows the approved design<br><b>And</b> failures do not corrupt the target gold table.</div><br><div><b>Update development documentation and configuration references</b><br><b>Given</b> the gold load implementation is complete<br><b>When</b> the development artifacts are reviewed<br><b>Then</b> notebook, task, pipeline, parameters, and operational notes are documented<br><b>And</b> configuration values are externalized rather than hardcoded.</div><br><div><b>Validate performance and data quality for Dev loads</b><br><b>Given</b> the pipeline loads distressed inventory data into North Star<br><b>When</b> Dev validation runs complete<br><b>Then</b> row counts, key uniqueness, required field population, and execution duration are captured<br><b>And</b> performance or data quality issues are tracked before promotion.</div>'
    }
    @{
        Title = "Journey Inspirations - Distressed Inventory - Per-Customer Event Hub Write Stream Development"
        Description = '<div><b>Given</b> the North Star gold table load is available in Dev and Event Hub requirements are defined<br><b>When</b> the team develops the write stream job<br><b>Then</b> the job reads the gold table as source and writes per-customer distressed inventory events to the target Event Hub<br><b>And</b> the published JSON payload follows the approved event contract and retention expectations</div><br><div><b>Context:</b> This story implements the streaming publisher that turns gold table records into per-customer events for Journey Inspirations distressed inventory. Payload content and Event Hub retention must align with downstream consumer reading plans.</div>'
        AcceptanceCriteria = '<div><b>Read gold table records for event publishing</b><br><b>Given</b> the North Star gold table contains distressed inventory records<br><b>When</b> the write stream job executes<br><b>Then</b> eligible records are read using the approved source filters, keys, and watermarking approach<br><b>And</b> duplicate or already-published records are handled according to the approved design.</div><br><div><b>Publish per-customer events to Event Hub</b><br><b>Given</b> the target Event Hub namespace and topic are available<br><b>When</b> event publishing runs<br><b>Then</b> one valid event is written per intended customer event using the approved JSON payload<br><b>And</b> event metadata supports downstream traceability and replay expectations.</div><br><div><b>Handle publishing errors and malformed payloads</b><br><b>Given</b> Event Hub writes may fail or records may not meet payload requirements<br><b>When</b> the stream job detects a write failure, malformed payload, or missing required field<br><b>Then</b> the error is logged and handled using the approved retry or quarantine strategy<br><b>And</b> failures do not silently drop customer events.</div><br><div><b>Document stream configuration and event contract</b><br><b>Given</b> the write stream job is implemented<br><b>When</b> development documentation is updated<br><b>Then</b> source table configuration, Event Hub target configuration, payload schema, retention assumptions, and operational steps are documented<br><b>And</b> downstream teams can validate how to consume the events.</div><br><div><b>Validate stream reliability and observability</b><br><b>Given</b> the stream job publishes per-customer events<br><b>When</b> Dev test runs are completed<br><b>Then</b> throughput, latency, retry behavior, logging, and alerting expectations are reviewed<br><b>And</b> gaps are tracked before Stage promotion.</div>'
    }
    @{
        Title = "Journey Inspirations - Distressed Inventory - Dev End-to-End Pipeline Validation"
        Description = '<div><b>Given</b> the gold table load pipeline and Event Hub write stream job are implemented in Dev<br><b>When</b> the team tests the end-to-end Journey Inspirations distressed inventory flow<br><b>Then</b> source data loads into North Star and per-customer events are published to Event Hub successfully<br><b>And</b> validation evidence is captured for readiness to parameterize and promote through CICD</div><br><div><b>Context:</b> This story validates the complete Dev path from the Jeremy-provided source table through North Star gold table load and Event Hub event publishing. It should produce evidence that the development flow works before Omega parameterization and Stage promotion.</div>'
        AcceptanceCriteria = '<div><b>Run the full Dev pipeline successfully</b><br><b>Given</b> Dev source access, gold table load, and Event Hub publishing are configured<br><b>When</b> the end-to-end pipeline is executed<br><b>Then</b> the flow completes from source table read to North Star gold table load to Event Hub publish<br><b>And</b> each pipeline step reports a successful completion status.</div><br><div><b>Validate source-to-gold-to-event outputs</b><br><b>Given</b> the Dev pipeline has completed<br><b>When</b> validation checks are run<br><b>Then</b> row counts, key-level reconciliation, required fields, and event payload samples match expected outcomes<br><b>And</b> discrepancies are documented with severity and owner.</div><br><div><b>Handle Dev test failures and data defects</b><br><b>Given</b> Dev validation may detect pipeline, data, or Event Hub failures<br><b>When</b> a failure occurs<br><b>Then</b> the team captures logs, failed step details, sample records, and remediation actions<br><b>And</b> failed runs can be corrected and rerun without corrupting target data or duplicating events unexpectedly.</div><br><div><b>Capture test evidence and operational notes</b><br><b>Given</b> end-to-end Dev validation is complete<br><b>When</b> evidence is prepared for review<br><b>Then</b> test results, validation queries, payload examples, pipeline run links, and known limitations are documented<br><b>And</b> evidence is available to engineering, product, platform, and downstream stakeholders.</div><br><div><b>Assess readiness for Stage promotion</b><br><b>Given</b> the Dev pipeline has been tested end to end<br><b>When</b> promotion readiness is reviewed<br><b>Then</b> configuration, performance, data quality, and consumer impact concerns are assessed<br><b>And</b> unresolved issues are addressed before Omega parameterization and CICD promotion.</div>'
    }
    @{
        Title = "Journey Inspirations - Distressed Inventory - Omega Parameterization and Stage CICD Promotion"
        Description = '<div><b>Given</b> the Dev end-to-end flow has been validated for Journey Inspirations distressed inventory<br><b>When</b> the team parameterizes the code using Omega contracts and promotes through CICD<br><b>Then</b> environment-specific configuration is externalized and the solution is deployed to Stage through the approved pipeline<br><b>And</b> Stage validation confirms the promoted pipeline and Event Hub publishing configuration are ready for downstream testing</div><br><div><b>Context:</b> This story covers parameterizing Dev code using Omega with contract configuration and moving the implementation to Stage via CICD. It depends on successful Dev validation and should avoid hardcoded environment values.</div>'
        AcceptanceCriteria = '<div><b>Parameterize environment configuration with Omega contracts</b><br><b>Given</b> Dev implementation artifacts are validated<br><b>When</b> Omega contract configuration is added<br><b>Then</b> source table, North Star gold table, Event Hub, credentials references, and environment-specific settings are parameterized<br><b>And</b> no hardcoded Dev, Stage, or Prod values remain in code.</div><br><div><b>Promote artifacts to Stage through CICD</b><br><b>Given</b> parameterized artifacts are committed and ready for promotion<br><b>When</b> the CICD process runs for Stage<br><b>Then</b> notebooks, tasks, pipelines, contracts, and stream job configuration are deployed to Stage successfully<br><b>And</b> deployment records identify artifact versions and pipeline run details.</div><br><div><b>Handle contract or promotion failures</b><br><b>Given</b> contract validation or CICD promotion may fail<br><b>When</b> the pipeline detects invalid configuration, missing approvals, or deployment errors<br><b>Then</b> the failure is reported with actionable details and remediation ownership<br><b>And</b> secrets or sensitive configuration values are not exposed in logs.</div><br><div><b>Update Stage deployment documentation</b><br><b>Given</b> Stage promotion has been completed<br><b>When</b> documentation is finalized<br><b>Then</b> Omega contract references, environment parameters, CICD run links, validation steps, and support notes are documented<br><b>And</b> engineering and operations teams can repeat or troubleshoot the Stage deployment.</div><br><div><b>Validate Stage readiness and consumer impact</b><br><b>Given</b> the solution is deployed to Stage<br><b>When</b> Stage smoke checks are performed<br><b>Then</b> the gold table load and Event Hub publishing configuration are verified for Stage<br><b>And</b> consumer-facing payload behavior, retention expectations, reliability, and monitoring are confirmed before further promotion.</div>'
    }
)

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
$iteration = $parent.fields.'System.IterationPath'
$parentTags = @($parent.fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$tags = @($parentTags + "AI-StoryWriting" + "Journey Inspirations" + "Distressed Inventory" | Sort-Object -Unique) -join "; "
Write-Host "PARENT id=$parentId type=$($parent.fields.'System.WorkItemType') project=$project area=$area iteration=$iteration tags=$tags"

foreach ($story in $stories) {
    $escapedTitle = $story.Title.Replace("'", "''")
    $duplicateWiql = "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.Title] = '$escapedTitle'"
    $duplicates = az boards query --organization $org --project $project --wiql $duplicateWiql --output json | ConvertFrom-Json
    if ($duplicates.Count -gt 0) {
        $duplicateId = $duplicates[0].id
        Write-Host "DUPLICATE duplicate_exists title=$($story.Title) id=$duplicateId url=$org/$project/_workitems/edit/$duplicateId"
        exit 10
    }
    Write-Host "DUPLICATE none title=$($story.Title)"
}

$rankWiql = "SELECT [System.Id], [Microsoft.VSTS.Common.StackRank] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.IterationPath] UNDER '$iteration' ORDER BY [Microsoft.VSTS.Common.StackRank] ASC"
$rankItems = az boards query --organization $org --project $project --wiql $rankWiql --output json | ConvertFrom-Json
$priorMinRank = $null
if ($rankItems.Count -gt 0) {
    $rankValue = $rankItems[0].fields.'Microsoft.VSTS.Common.StackRank'
    if ($null -ne $rankValue) { $priorMinRank = [double]$rankValue }
}
if ($null -eq $priorMinRank) {
    $baseRank = -1000000
    Write-Host "RANK priorMin=unavailable base=$baseRank"
} else {
    $baseRank = $priorMinRank - 1000
    Write-Host "RANK priorMin=$priorMinRank base=$baseRank"
}

$createdIds = @()
$index = 0
foreach ($story in $stories) {
    $stackRank = $baseRank - ($index * 100)
    $created = az boards work-item create `
        --organization $org `
        --project $project `
        --type "User Story" `
        --title $story.Title `
        --area $area `
        --iteration $iteration `
        --fields "System.Description=$($story.Description)" `
                 "Microsoft.VSTS.Common.AcceptanceCriteria=$($story.AcceptanceCriteria)" `
                 "Microsoft.VSTS.Scheduling.StoryPoints=0" `
                 "Microsoft.VSTS.Common.Priority=2" `
                 "AAIT.Ready=Yes" `
                 "AAIT.WorkType=4. Software / UX" `
                 "System.State=Backlog" `
                 "System.Tags=$tags" `
                 "Microsoft.VSTS.Common.StackRank=$stackRank" `
        --output json | ConvertFrom-Json

    $createdId = $created.id
    if (-not $createdId) { throw "Create did not return a work item ID for $($story.Title)." }
    Write-Host "CREATE id=$createdId rank=$stackRank title=$($story.Title)"

    az boards work-item relation add --id $createdId --organization $org --relation-type parent --target-id $parentId --output json | Out-Null
    Write-Host "LINK child=$createdId parent=$parentId"
    $createdIds += $createdId
    $index++
}

foreach ($createdId in $createdIds) {
    $verified = az boards work-item show --id $createdId --organization $org --expand all --output json | ConvertFrom-Json
    $verifiedParentId = Get-ParentId -WorkItem $verified
    $verifiedTitle = $verified.fields.'System.Title'
    $expected = @($stories | Where-Object { $_.Title -eq $verifiedTitle }) | Select-Object -First 1
    if (-not $expected) { throw "Unexpected verified title for $createdId." }
    $checks = @(
        ($verified.fields.'System.WorkItemType' -eq "User Story"),
        ($verified.fields.'System.State' -eq "Backlog"),
        ($verified.fields.'System.AreaPath' -eq $area),
        ($verified.fields.'System.IterationPath' -eq $iteration),
        ($verifiedParentId -eq $parentId),
        ($verified.fields.'System.Tags' -like "*AI-StoryWriting*"),
        ($verified.fields.'System.Tags' -like "*4Q26*")
    )
    if ($checks -contains $false) { throw "Verification failed for created work item $createdId." }
    Write-Host "VERIFY id=$createdId url=$org/$project/_workitems/edit/$createdId type=$($verified.fields.'System.WorkItemType') state=$($verified.fields.'System.State') area=$($verified.fields.'System.AreaPath') iteration=$($verified.fields.'System.IterationPath') tags=$($verified.fields.'System.Tags') stackRank=$($verified.fields.'Microsoft.VSTS.Common.StackRank') parent=$verifiedParentId title=$verifiedTitle"
}