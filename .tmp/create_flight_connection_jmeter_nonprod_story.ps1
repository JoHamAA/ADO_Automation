$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"
$area = "PassengerDataHub"
$iteration = "PassengerDataHub"
$title = "PaxHub - Migration to MongoDB - Flight Connection Details - Create Jmeter Load test (NONPROD)"
$tags = "AI-StoryWriting; Migration to MongoDB; Flight Connection Details"

$description = '<div><b>Given</b> the Flight Connection Details MongoDB API requires performance evaluation before load testing begins<br><b>When</b> the team prepares a JMeter load-test plan in the NONPROD environment<br><b>Then</b> the test can exercise representative Flight Connection Details API traffic against the MongoDB implementation<br><b>And</b> the test configuration is ready for execution and later performance tuning</div><br><div><b>Context:</b> Create the JMeter load test in preparation for NONPROD load testing of the Flight Connection Details MongoDB API. The load-test assets are located on non-prod VM <b>chazrmcdmne01.corpaa.aa.com</b>. Define representative request data, concurrency, ramp-up, duration, assertions, parameterization, result collection, and execution instructions. This story prepares the test; subsequent work will execute the load test, compare performance statistics, and fine tune the API if needed.</div>'

$acceptanceCriteria = '<div><b>Create a representative JMeter test plan</b><br><b>Given</b> the Flight Connection Details MongoDB API endpoint and representative NONPROD request data are available<br><b>When</b> the JMeter test plan is created<br><b>Then</b> it includes parameterized requests, representative PNR or connection inputs, configurable concurrency, ramp-up, duration, and assertions for successful responses<br><b>And</b> the plan can be executed repeatedly without hardcoded credentials or environment-specific secrets.</div><br><div><b>Handle failed requests and invalid test data</b><br><b>Given</b> the API may return errors, timeouts, malformed responses, or invalid input results during a load run<br><b>When</b> the JMeter plan encounters those conditions<br><b>Then</b> assertions and listeners identify failures with actionable status and response details<br><b>And</b> the test does not hide errors or create uncontrolled load against the NONPROD service.</div><br><div><b>Document test configuration and execution</b><br><b>Given</b> the load-test assets will run from chazrmcdmne01.corpaa.aa.com<br><b>When</b> the preparation work is completed<br><b>Then</b> the JMeter file, input data, runtime parameters, prerequisites, execution commands, and result-location guidance are documented<br><b>And</b> sensitive values are supplied through approved configuration or environment variables rather than committed to the test plan.</div><br><div><b>Prepare reliable performance measurement</b><br><b>Given</b> the purpose of the test is to evaluate MongoDB API performance and support later tuning<br><b>When</b> the JMeter plan is reviewed before execution<br><b>Then</b> it captures response time, throughput, error rate, and relevant resource or server metrics needed for baseline comparison<br><b>And</b> the test design supports a controlled comparison with pre-implementation statistics without changing production data.</div>'

Write-Host "PARENT none"

$escapedTitle = $title.Replace("'", "''")
$duplicateWiql = "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.Title] = '$escapedTitle'"
$duplicates = @(az boards query --organization $org --project $project --wiql $duplicateWiql --output json | ConvertFrom-Json)
if ($duplicates.Count -gt 0) {
    throw "DUPLICATE duplicate_exists title=$title id=$($duplicates[0].id) url=$org/$project/_workitems/edit/$($duplicates[0].id)"
}
Write-Host "DUPLICATE none title=$title"

$stackRank = -1000000
Write-Host "RANK priorMin=unavailable fallback=$stackRank"

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

if (-not $created.id) { throw "CREATE failed to return a work item ID." }
Write-Host "CREATE id=$($created.id) rank=$stackRank title=$title"
Write-Host "LINK none child=$($created.id)"

$verified = az boards work-item show --id $created.id --organization $org --expand all --output json | ConvertFrom-Json
$parentRelation = @($verified.relations | Where-Object { $_.rel -eq "System.LinkTypes.Hierarchy-Reverse" }) | Select-Object -First 1
$verifiedRank = [double]$verified.fields.'Microsoft.VSTS.Common.StackRank'
$checks = @(
    ($verified.id -eq $created.id),
    ($verified.fields.'System.Title' -eq $title),
    ($verified.fields.'System.WorkItemType' -eq "User Story"),
    ($verified.fields.'System.State' -eq "Backlog"),
    ($verified.fields.'System.AreaPath' -eq $area),
    ($verified.fields.'System.IterationPath' -eq $iteration),
    ($verified.fields.'System.Tags' -like "*AI-StoryWriting*"),
    ($null -eq $parentRelation),
    ($verified.fields.'System.Description' -eq $description),
    ($verified.fields.'Microsoft.VSTS.Common.AcceptanceCriteria' -eq $acceptanceCriteria),
    ($verifiedRank -eq $stackRank)
)
if ($checks -contains $false) { throw "VERIFY failed for work item $($created.id)." }

Write-Host "VERIFY id=$($created.id) url=$org/$project/_workitems/edit/$($created.id) type=$($verified.fields.'System.WorkItemType') state=$($verified.fields.'System.State') area=$($verified.fields.'System.AreaPath') iteration=$($verified.fields.'System.IterationPath') tags=$($verified.fields.'System.Tags') stackRank=$verifiedRank parent=none"
Write-Host "VERIFY_DESCRIPTION persisted=true"
Write-Host "VERIFY_ACCEPTANCE_CRITERIA persisted=true"