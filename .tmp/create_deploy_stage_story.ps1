$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"

$title = "PaxHub - Migration to MongoDB - Flight Connection Details - KPASS - Deploy API to STAGE"

$desc = '<div><b>Given</b> the Flight Connection Details API and KPASS Apigee product are ready for STAGE deployment<br><b>When</b> executing deployment activities across non-prod and STAGE environments<br><b>Then</b> the API is deployed to QA West, STAGE East, and STAGE West environments<br><b>And</b> the KPASS Apigee product is promoted to STAGE for end-to-end integration testing</div><br><div><b>Context:</b> This involves deploying the API to QA West, STAGE East, and STAGE West. This also includes promoting the KPASS Apigee product to STAGE.</div>'

$ac = '<div><b>Scenario 1: Deploy API to QA West and STAGE environments</b><br><b>Given</b> built and verified deployment artifacts for the Flight Connection Details API<br><b>When</b> the deployment pipeline runs for QA West, STAGE East, and STAGE West<br><b>Then</b> the API services are successfully deployed and active across QA West, STAGE East, and STAGE West instances<br><b>And</b> health checks and smoke tests pass for all target regions.</div><br><div><b>Scenario 2: Promote KPASS Apigee product to STAGE</b><br><b>Given</b> the validated KPASS Apigee product configuration<br><b>When</b> Apigee product configuration is promoted to STAGE<br><b>Then</b> the KPASS Apigee product is published and operational in the STAGE Apigee environment<br><b>And</b> routing to STAGE East and STAGE West API backends is verified.</div><br><div><b>Scenario 3: End-to-End validation in STAGE</b><br><b>Given</b> deployed API instances and the KPASS Apigee product in STAGE<br><b>When</b> test requests are sent through Apigee in STAGE<br><b>Then</b> requests are properly authorized and return valid flight connection details responses from both STAGE regions.</div>'

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
