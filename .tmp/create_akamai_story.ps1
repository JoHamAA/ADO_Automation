$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"

$title = "PaxHub - Migration to MongoDB - Flight Connection Details - KPASS - Update API to PaxHub AKAMAI URL"

$desc = '<div><b>Given</b> KPASS APIs currently point to the KPASS Akamai endpoint rather than the internal PaxHub endpoint<br><b>When</b> updating the Akamai endpoint configuration to point to PaxHub''s Akamai URL<br><b>Then</b> traffic routes through the PaxHub endpoint without client impact<br><b>And</b> the team gains regional traffic distribution control instead of fixed 50/50 East/West routing</div><br><div><b>Context:</b> Currently for KPASS APIs, we are pointing to the KPASS Akamai endpoint and not internal PaxHub endpoint. We would like to update the Akamai Endpoint to PaxHub''s endpoint so that we will not have any client impact to change to a new endpoint. Pointing to PaxHub endpoint will also allow the team to manage traffic distribution by region as KPASS is set to exactly 50% traffic to East and 50% West.</div><br><div><b>Note:</b> Placeholder story to not lose track of work. Currently Prashant is in discussions with KPASS team.</div>'

$ac = '<div><b>Scenario 1: Update Akamai endpoint routing to PaxHub endpoint</b><br><b>Given</b> the KPASS Flight Connection Details API integration<br><b>When</b> the Akamai endpoint configuration is updated from the KPASS endpoint to the PaxHub Akamai URL<br><b>Then</b> client API requests route directly through PaxHub''s Akamai endpoint<br><b>And</b> clients experience zero breaking changes or endpoint URL modifications.</div><br><div><b>Scenario 2: Enable regional traffic distribution management</b><br><b>Given</b> traffic routing via PaxHub''s Akamai endpoint<br><b>When</b> regional traffic distribution rules are configured<br><b>Then</b> the team can dynamically manage traffic split percentages across East and West regions<br><b>And</b> the legacy rigid 50% East / 50% West traffic allocation is superseded.</div><br><div><b>Scenario 3: Validate zero client impact and endpoint health</b><br><b>Given</b> the updated PaxHub Akamai endpoint routing<br><b>When</b> API request traffic flows through the updated URL<br><b>Then</b> all API responses complete successfully with valid HTTP status codes<br><b>And</b> latency and error rate metrics remain within acceptable operational SLAs.</div>'

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
