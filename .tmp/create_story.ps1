$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"

$title = "PaxHub - Migration to MongoDB - LMRI - GraphQL API - Update departureDate response element to include departure time"
$desc = '<div><b>Given</b> the LMRI GraphQL API currently truncates the departure timestamp to date-only format (yyyy-MM-dd, e.g., "2026-08-27")<br><b>When</b> clients query departure details via the LMRI GraphQL API<br><b>Then</b> the ''departureDate'' field in the API response and schema is updated to include both local departure date and time in ''yyyy-MM-ddTHH:mm:ss'' format (e.g., "2026-08-27T17:29:00")<br><b>And</b> the GraphQL schema is updated to document local airport time and the new format string</div><br><div><b>Context:</b> Currently in the API, we are truncating the date time field to only show the date in the response. (yyyy-MM-dd) We want to include the time as well to give clients a precise time and allow clients to calculate accurate relative durations, should they need to. Today response "departureDate": "2026-08-27". Tomo''s response "departureDate": "2026-08-27T17:29:00".</div>'
$ac = '<div><b>Scenario 1: Verify departureDate response element includes local departure time</b><br><b>Given</b> a client sends a request to the LMRI GraphQL API<br><b>When</b> the response payload is generated for a flight<br><b>Then</b> the ''departureDate'' field is formatted as ''yyyy-MM-ddTHH:mm:ss'' (e.g., "2026-08-27T17:29:00")<br><b>And</b> the timestamp accurately reflects the local time at the departure airport.</div><br><div><b>Scenario 2: Update GraphQL schema definition and documentation</b><br><b>Given</b> the LMRI GraphQL API schema<br><b>When</b> the ''departureDate'' field documentation is inspected<br><b>Then</b> the schema states ''departureDate'' represents the departure date and local time of the departure airport<br><b>And</b> the schema explicitly specifies the format ''yyyy-MM-ddTHH:mm:ss''.</div><br><div><b>Scenario 3: Backward compatibility and valid API response</b><br><b>Given</b> active API clients consuming the LMRI GraphQL API<br><b>When</b> the updated response payload is returned<br><b>Then</b> the response completes with HTTP 200 OK<br><b>And</b> no schema parsing or validation errors occur.</div>'

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
             "System.Tags=LMRI; MongoPNR; AI-StoryWriting" `
    --output json | ConvertFrom-Json

$newId = $createResult.id
Write-Host "Created Work Item ID: $newId"

# 2. Add Parent link to Feature 2921611
az boards work-item relation add `
    --id $newId `
    --organization $org `
    --relation-type parent `
    --target-id 2921611 `
    --output json | Out-Null

Write-Host "Linked $newId to Parent Feature 2921611"

# 3. Move story to top of backlog by setting StackRank lower than current lowest
$topQuery = az boards query --organization $org --project $project --wiql "SELECT [Microsoft.VSTS.Common.StackRank] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' ORDER BY [Microsoft.VSTS.Common.StackRank] ASC" --output json | ConvertFrom-Json
$lowestRank = 1000
if ($topQuery -and $topQuery.Count -gt 0 -and $topQuery[0].fields.'Microsoft.VSTS.Common.StackRank') {
    $lowestRank = [double]$topQuery[0].fields.'Microsoft.VSTS.Common.StackRank' - 1000
}

az boards work-item update --id $newId --organization $org --fields "Microsoft.VSTS.Common.StackRank=$lowestRank" --output json | Out-Null
Write-Host "StackRank updated to $lowestRank"
