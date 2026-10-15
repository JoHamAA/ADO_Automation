$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"

$title = "PaxHub - Migration to MongoDB - Flight Connection Details - KPASS - Load Testing"

$desc = '<div><b>Given</b> the KPASS Flight Connection Details API is deployed in the performance test environment<br><b>When</b> performance optimizations are applied and load tests are executed under production-representative load<br><b>Then</b> baseline performance metrics and post-optimization load testing results are captured, validated, and documented</div><br><div><b>Context:</b> This story covers performance optimization and load testing for the KPASS Flight Connection Details API (modeled after story 3075105) to produce measurable, recorded results that inform capacity planning and SLA commitments.</div>'

$ac = '<div><b>Scenario 1: Load test executed successfully</b><br><b>Given</b> the KPASS Flight Connection Details API is deployed in a performance test environment<br><b>When</b> a load test simulating production-level traffic is executed<br><b>Then</b> the test completes without service failure<br><b>And</b> response time, throughput, and error rate metrics are captured.</div><br><div><b>Scenario 2: Performance optimizations validated</b><br><b>Given</b> optimizations have been applied to the KPASS Flight Connection Details API<br><b>When</b> the load test is re-run under the same conditions<br><b>Then</b> the results show measurable improvement over the pre-optimization baseline<br><b>And</b> results are documented for review.</div><br><div><b>Scenario 3: Results captured and stored</b><br><b>Given</b> load testing is complete<br><b>When</b> results are published<br><b>Then</b> a performance report is available with baseline vs. optimized comparison<br><b>And</b> the report is shared with the team for sign-off.</div>'

# 1. Create work item
$createResult = az boards work-item create `
    --organization $org `
    --project $project `
    --type "User Story" `
    --title $title `
    --area $project `
    --iteration $project `
    --fields "System.Description=$desc" `
             "Microsoft.VSTS.Common.AcceptanceCriteria=$ac" `
             "Microsoft.VSTS.Scheduling.StoryPoints=0" `
             "AAIT.WorkType=4. Software / UX" `
             "Microsoft.VSTS.Common.Priority=2" `
             "AAIT.Ready=Yes" `
             "System.Tags=AI-StoryWriting; MongoPNR; StandbyAPI" `
    --output json | ConvertFrom-Json

$newId = $createResult.id
Write-Host "Created Work Item ID: $newId"

# 2. Add Parent link to Feature 3066956
az boards work-item relation add `
    --id $newId `
    --organization $org `
    --relation-type parent `
    --target-id 3066956 `
    --output json | Out-Null

Write-Host "Linked $newId to Parent Feature 3066956"

# 3. Move story to top of backlog by setting StackRank lower than current lowest
$topQuery = az boards query --organization $org --project $project --wiql "SELECT [Microsoft.VSTS.Common.StackRank] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' ORDER BY [Microsoft.VSTS.Common.StackRank] ASC" --output json | ConvertFrom-Json
$lowestRank = 1000
if ($topQuery -and $topQuery.Count -gt 0 -and $topQuery[0].fields.'Microsoft.VSTS.Common.StackRank') {
    $lowestRank = [double]$topQuery[0].fields.'Microsoft.VSTS.Common.StackRank' - 1000
}

az boards work-item update --id $newId --organization $org --fields "Microsoft.VSTS.Common.StackRank=$lowestRank" --output json | Out-Null
Write-Host "StackRank updated to $lowestRank"
