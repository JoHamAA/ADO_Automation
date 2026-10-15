$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"

$title = "PaxHub - Migration to MongoDB - Flight Connection Details - KPASS - Update API to Connect to Mongo Using Managed Identity"

$desc = '<div><b>Given</b> the Flight Connection Details API currently connects to MongoDB using username and password credentials<br><b>When</b> updating database authentication configuration to leverage Azure Managed Identity<br><b>Then</b> the API connects securely to MongoDB using Managed Identity tokens without hardcoded credentials or key rotation overhead<br><b>And</b> database connection parameters are updated across deployment environments</div><br><div><b>Context:</b> Currently, the API is connecting to MongoDB using username and password. We want to connect to the database via managed identity so that we do not have to worry about credential management in terms of key rotations as well as no exposure to the credentials in the code.</div>'

$ac = '<div><b>Scenario 1: Configure Managed Identity authentication for MongoDB connection</b><br><b>Given</b> the Flight Connection Details API codebase and MongoDB configuration<br><b>When</b> the database connection logic is updated to use Azure Managed Identity<br><b>Then</b> connection strings and code eliminate reliance on static username and password credentials<br><b>And</b> the application retrieves access tokens via Managed Identity.</div><br><div><b>Scenario 2: Validate Managed Identity access in non-production environments</b><br><b>Given</b> the API is deployed to non-production environments with assigned Managed Identity roles<br><b>When</b> database operations are performed<br><b>Then</b> database queries, inserts, and updates complete successfully without authentication errors<br><b>And</b> no credentials or secrets are logged or exposed in application configuration.</div><br><div><b>Scenario 3: Verify security compliance and credential elimination</b><br><b>Given</b> Managed Identity authentication is enabled<br><b>When</b> security and code scanning reviews are performed<br><b>Then</b> static database credentials are confirmed removed from repository code and environment variables<br><b>And</b> database access adheres to AA cloud security standards.</div>'

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
