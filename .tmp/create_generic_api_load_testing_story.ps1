$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"
$area = "PassengerDataHub"
$iteration = "PassengerDataHub"
$title = "PaxHub - Migration to MongoDB - Load Testing for APIs"
$tags = "AI-StoryWriting; Migration to MongoDB; Load Testing"

$description = '<div><b>Given</b> the PNR Graph and LMRI Graph APIs are being migrated to MongoDB and require performance validation<br><b>When</b> a series of regular-traffic, high-peak, and ad hoc load tests is prepared and executed<br><b>Then</b> a generic baseline of API performance metrics is established and compared across representative traffic conditions<br><b>And</b> findings identify whether tuning or additional performance work is needed before release</div><br><div><b>Context:</b> Perform generic load testing for the PNR Graph and LMRI Graph APIs to establish baseline metrics and verify that the APIs perform well under regular traffic and high peak traffic loads. This story covers shared and ad hoc load-testing preparation, execution, monitoring, results capture, and comparison with agreed baseline statistics. Scenario-specific load tests will be added as needed without changing the reusable test approach.</div>'

$acceptanceCriteria = '<div><b>Establish a reusable load-test baseline</b><br><b>Given</b> PNR Graph and LMRI Graph API endpoints, representative data, and expected regular traffic profiles are available<br><b>When</b> the generic load-test plan is prepared and executed<br><b>Then</b> baseline response time, throughput, error rate, concurrency, and resource metrics are captured for both APIs<br><b>And</b> the test configuration and baseline results are repeatable and versioned.</div><br><div><b>Validate regular and high-peak traffic behavior</b><br><b>Given</b> the APIs must support normal traffic and high peak traffic loads<br><b>When</b> controlled load tests run across the approved traffic profiles<br><b>Then</b> API behavior, capacity, latency, error handling, and downstream impact are measured<br><b>And</b> the tests avoid uncontrolled traffic and do not modify production data.</div><br><div><b>Support ad hoc and scenario-specific testing</b><br><b>Given</b> additional scenarios may require focused load tests during the MongoDB migration<br><b>When</b> an ad hoc scenario is requested<br><b>Then</b> the reusable test approach supports scenario-specific inputs, concurrency, ramp-up, duration, assertions, and reporting<br><b>And</b> assumptions, test data, and deviations from the generic baseline are documented.</div><br><div><b>Compare results and identify tuning actions</b><br><b>Given</b> load-test results have been collected for PNR Graph and LMRI Graph<br><b>When</b> results are compared with the baseline and agreed performance objectives<br><b>Then</b> regressions, capacity constraints, and tuning opportunities are clearly identified<br><b>And</b> remediation owners, follow-up tests, and release-readiness decisions are documented.</div>'

Write-Host "PARENT none"
$escapedTitle = $title.Replace("'", "''")
$duplicateWiql = "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.Title] = '$escapedTitle'"
$duplicates = @(az boards query --organization $org --project $project --wiql $duplicateWiql --output json | ConvertFrom-Json)
if ($duplicates.Count -gt 0) { throw "DUPLICATE duplicate_exists title=$title id=$($duplicates[0].id) url=$org/$project/_workitems/edit/$($duplicates[0].id)" }
Write-Host "DUPLICATE none title=$title"

$stackRank = -1000000
Write-Host "RANK priorMin=unavailable fallback=$stackRank"
$created = az boards work-item create --organization $org --project $project --type "User Story" --title $title --area $area --iteration $iteration --fields "System.Description=$description" "Microsoft.VSTS.Common.AcceptanceCriteria=$acceptanceCriteria" "Microsoft.VSTS.Scheduling.StoryPoints=0" "Microsoft.VSTS.Common.Priority=2" "AAIT.Ready=Yes" "AAIT.WorkType=4. Software / UX" "System.State=Backlog" "System.Tags=$tags" "Microsoft.VSTS.Common.StackRank=$stackRank" --output json | ConvertFrom-Json
if (-not $created.id) { throw "CREATE failed to return a work item ID." }
Write-Host "CREATE id=$($created.id) title=$title"
Write-Host "LINK none child=$($created.id)"

$verified = az boards work-item show --id $created.id --organization $org --expand all --output json | ConvertFrom-Json
$parentRelation = @($verified.relations | Where-Object { $_.rel -eq "System.LinkTypes.Hierarchy-Reverse" }) | Select-Object -First 1
if ($verified.fields.'System.Title' -ne $title -or $verified.fields.'System.WorkItemType' -ne "User Story" -or $verified.fields.'System.State' -ne "Backlog" -or $verified.fields.'System.AreaPath' -ne $area -or $verified.fields.'System.IterationPath' -ne $iteration -or $null -ne $parentRelation -or $verified.fields.'System.Description' -ne $description -or $verified.fields.'Microsoft.VSTS.Common.AcceptanceCriteria' -ne $acceptanceCriteria) { throw "VERIFY failed for work item $($created.id)." }
Write-Host "VERIFY id=$($created.id) url=$org/$project/_workitems/edit/$($created.id) type=UserStory state=$($verified.fields.'System.State') area=$($verified.fields.'System.AreaPath') iteration=$($verified.fields.'System.IterationPath') tags=$($verified.fields.'System.Tags') stackRank=$($verified.fields.'Microsoft.VSTS.Common.StackRank') parent=none description=true acceptanceCriteria=true"