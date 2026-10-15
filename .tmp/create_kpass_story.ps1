$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"

$title = "PaxHub - Migration to MongoDB - Flight Connection Details - KPASS - Create Apigee Product"

$desc = '<div><b>Given</b> authorization via Apigee is required to access PaxHub APIs<br><b>When</b> configuring access control for the Flight Connection Details KPASS integration<br><b>Then</b> the KPASS Apigee product is created with the required API proxies, quotas, and OAuth security settings<br><b>And</b> the Apigee product is promoted to the QA environment for verification</div><br><div><b>Context:</b> In order to get access to our APIs, we need some form of authorization by going through APIGEE. We need to create the Kpass Apigee product and promote it to QA.</div>'

$ac = '<div><b>Scenario 1: Create KPASS Apigee product configuration</b><br><b>Given</b> Apigee product specifications for the Flight Connection Details API<br><b>When</b> the KPASS Apigee product is created<br><b>Then</b> the product includes the correct target API proxies, resource paths, rate limits, and security scopes<br><b>And</b> the product configuration is validated against Apigee standards.</div><br><div><b>Scenario 2: Promote KPASS Apigee product to QA environment</b><br><b>Given</b> the KPASS Apigee product is created and validated<br><b>When</b> the deployment pipeline promotes the configuration to QA<br><b>Then</b> the KPASS product is successfully deployed and active in the QA Apigee environment<br><b>And</b> test API keys/credentials can be provisioned against the QA product.</div><br><div><b>Scenario 3: Verify API access authorization in QA</b><br><b>Given</b> a test client application configured with QA KPASS credentials<br><b>When</b> a request is made to the Flight Connection Details API via Apigee in QA<br><b>Then</b> Apigee successfully authorizes the request and routes traffic to the backend service<br><b>And</b> unauthorized requests without valid KPASS product entitlement are rejected with HTTP 401/403.</div>'

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
