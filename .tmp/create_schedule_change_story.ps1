$ErrorActionPreference = "Stop"
$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"
$parentId = 2951224
$title = "PaxHub - Migration to MongoDB - PNR PROCESSOR - SCHEDULE CHANGE - Implement Single Repo, Multiple Function App Strategy (NONPROD)"
$description = '<div><b>Given</b> the schedule change processor implementation is contained in the <code>ph-backend-pnr-processor</code> repository and QA and STAGE function apps are available<br><b>When</b> the single-repository, multiple-function-app strategy is implemented for NONPROD<br><b>Then</b> the same codebase can be deployed to the schedule change processor function app<br><b>And</b> the function apps can connect to MongoDB and are configured with the required Service Bus permissions</div><br><div><b>Context:</b> As a follow-up to spike story <a href="https://dev.azure.com/AmericanAirlines/PassengerDataHub/_workitems/edit/3002461">3002461</a>, implement the defined change in the Mongo PNR PROCESSOR repository (<code>ph-backend-pnr-processor</code>) so the same code can be deployed to the schedule change processor function app. QA and STAGE function apps are created. There are currently no active messages in the schedule change Service Bus queue, but the infrastructure must be ready to process messages when they become available.</div>'
$acceptanceCriteria = '<div><b>Single repository deploys to multiple function apps</b><br><b>Given</b> the <code>ph-backend-pnr-processor</code> repository contains the schedule change processor code<br><b>When</b> the NONPROD deployment process is executed for the applicable function apps<br><b>Then</b> the same repository code is deployable to the standard PNR processor and schedule change processor function apps<br><b>And</b> each function app starts successfully with its intended configuration.</div><br><div><b>Required Service Bus roles are configured</b><br><b>Given</b> the schedule change function app must read from its Service Bus queue<br><b>When</b> its managed identity and access configuration are reviewed<br><b>Then</b> the required Service Bus roles are assigned to the correct function app identity<br><b>And</b> the application can connect to and read from the queue without authorization errors.</div><br><div><b>MongoDB connectivity works without embedded credentials</b><br><b>Given</b> the function apps require access to MongoDB<br><b>When</b> the deployed application initializes and performs a database operation<br><b>Then</b> the connection succeeds using the approved authentication and configuration approach<br><b>And</b> credentials are not hardcoded, exposed in configuration, or written to application logs.</div><br><div><b>Unexpected configuration and queue conditions are handled safely</b><br><b>Given</b> the schedule change queue has no active messages or contains an unexpected message payload or configuration value<br><b>When</b> the function app polls the queue or attempts to process a message<br><b>Then</b> the application remains available and records an actionable diagnostic without causing an unhandled failure<br><b>And</b> invalid messages are handled according to the approved retry, dead-letter, or error-management behavior.</div><br><div><b>NONPROD deployment and validation are documented</b><br><b>Given</b> the QA and STAGE function apps are available<br><b>When</b> implementation and deployment validation are completed<br><b>Then</b> deployment steps, function app configuration, Service Bus permissions, MongoDB connectivity, and validation results are documented<br><b>And</b> the implementation is ready for review and promotion through the NONPROD environments.</div>'

$rankData = az.cmd boards query --organization $org --project $project --wiql "SELECT [Microsoft.VSTS.Common.StackRank] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' ORDER BY [Microsoft.VSTS.Common.StackRank] ASC" --output json | ConvertFrom-Json
$ranked = @($rankData | ForEach-Object { $_ } | Where-Object { $null -ne $_.fields.'Microsoft.VSTS.Common.StackRank' })
$stackRank = 1000
if ($ranked.Count -gt 0) { $stackRank = [double]$ranked[0].fields.'Microsoft.VSTS.Common.StackRank' - 1000 }

$result = az.cmd boards work-item create `
    --organization $org `
    --project $project `
    --type "User Story" `
    --title $title `
    --area $project `
    --iteration $project `
    --fields "System.Description=$description" `
             "Microsoft.VSTS.Common.AcceptanceCriteria=$acceptanceCriteria" `
             "Microsoft.VSTS.Scheduling.StoryPoints=0" `
             "AAIT.WorkType=4. Software / UX" `
             "Microsoft.VSTS.Common.Priority=2" `
             "AAIT.Ready=Yes" `
             "System.Tags=MongoPNR; Schedule Change Processor; AI-StoryWriting" `
             "Microsoft.VSTS.Common.StackRank=$stackRank" `
    --output json | ConvertFrom-Json

if (-not $result.id) { throw "Create returned no work item ID." }

az.cmd boards work-item relation add --id $result.id --organization $org --relation-type parent --target-id $parentId --output none
az.cmd boards work-item show --id $result.id --organization $org --output json > "$env:TEMP\verify_schedule_change_$($result.id).json"
$verified = Get-Content "$env:TEMP\verify_schedule_change_$($result.id).json" -Raw | ConvertFrom-Json
Write-Output ("Created: " + $verified.id)
Write-Output ("Title: " + $verified.fields.'System.Title')
Write-Output ("Parent: " + $verified.fields.'System.Parent')
Write-Output ("Tags: " + $verified.fields.'System.Tags')
Write-Output ("StackRank: " + $verified.fields.'Microsoft.VSTS.Common.StackRank')
