$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"
$tags = "3Q26; MongoPNR; AI-StoryWriting"

$stories = @(
    @{
        Title = "PaxHub - Migration to MongoDB - LMRI - GraphQL API - PROD Readiness"
        Description = '<div><b>Given</b> the LMRI GraphQL API migration to MongoDB is ready for production-readiness review<br><b>When</b> production validation, monitoring, documentation, and approvals are completed<br><b>Then</b> the LMRI GraphQL API is confirmed ready for production deployment</div><br><div><b>Context:</b> Prepare the LMRI GraphQL API and its MongoDB migration for production deployment.</div>'
        AcceptanceCriteria = '<div><b>Production readiness validation completed</b><br><b>Given</b> the LMRI GraphQL API is deployed in the production-like environment<br><b>When</b> functional, integration, and data validation checks are performed<br><b>Then</b> the API meets the required readiness criteria<br><b>And</b> validation results are documented.</div><br><div><b>Operational monitoring and support readiness established</b><br><b>Given</b> the API is preparing for production operation<br><b>When</b> monitoring, alerting, logging, and support procedures are reviewed<br><b>Then</b> required operational coverage is enabled<br><b>And</b> support documentation and ownership are available.</div><br><div><b>Readiness issues are controlled and resolved</b><br><b>Given</b> readiness checks identify missing configuration, unexpected data, or validation failures<br><b>When</b> an issue is found<br><b>Then</b> it is documented with an owner and resolution plan<br><b>And</b> unresolved blocking issues prevent production approval.</div><br><div><b>Production approval is documented</b><br><b>Given</b> technical and operational readiness activities are complete<br><b>When</b> required stakeholders review the results<br><b>Then</b> production approval or an explicit decision is recorded<br><b>And</b> deployment prerequisites are available to the release team.</div>'
    },
    @{
        Title = "PaxHub - Migration to MongoDB - LMRI - GraphQL API - PROD Deployment"
        Description = '<div><b>Given</b> the LMRI GraphQL API has passed production-readiness validation and received deployment approval<br><b>When</b> the approved release is deployed to production<br><b>Then</b> the LMRI GraphQL API is available in production and serves the migrated MongoDB-backed functionality</div><br><div><b>Context:</b> Deploy the LMRI GraphQL API MongoDB migration to production after readiness approval.</div>'
        AcceptanceCriteria = '<div><b>LMRI GraphQL API production deployment completed</b><br><b>Given</b> an approved LMRI GraphQL API release is available<br><b>When</b> the production deployment is executed<br><b>Then</b> the API is deployed successfully<br><b>And</b> production health checks pass.</div><br><div><b>Production API behavior is validated</b><br><b>Given</b> the API is deployed to production<br><b>When</b> authorized smoke and integration requests are submitted<br><b>Then</b> valid GraphQL responses are returned from the MongoDB-backed implementation<br><b>And</b> response behavior meets the approved API contract.</div><br><div><b>Deployment failures are handled without unstable service behavior</b><br><b>Given</b> deployment or post-deployment checks encounter an unexpected error, invalid configuration, or unavailable dependency<br><b>When</b> the release process responds to the failure<br><b>Then</b> the failure is surfaced through approved monitoring and deployment controls<br><b>And</b> the service is not left in an unverified or partially exposed state.</div><br><div><b>Production operations are monitored after release</b><br><b>Given</b> the production deployment and initial validation are complete<br><b>When</b> post-deployment monitoring is performed<br><b>Then</b> errors, latency, throughput, and MongoDB connectivity are reviewed<br><b>And</b> any required follow-up actions are documented and assigned.</div>'
    }
)

$createdIds = @()
foreach ($story in $stories) {
    $result = az boards work-item create `
        --organization $org `
        --project $project `
        --type "User Story" `
        --title $story.Title `
        --area $project `
        --iteration $project `
        --fields "System.Description=$($story.Description)" `
                 "Microsoft.VSTS.Common.AcceptanceCriteria=$($story.AcceptanceCriteria)" `
                 "Microsoft.VSTS.Scheduling.StoryPoints=0" `
                 "AAIT.WorkType=4. Software / UX" `
                 "Microsoft.VSTS.Common.Priority=2" `
                 "AAIT.Ready=Yes" `
                 "System.Tags=$tags" `
        --output json | ConvertFrom-Json

    if (-not $result.id) { throw "Create returned no work item ID for: $($story.Title)" }
    $createdIds += $result.id

    az boards work-item relation add `
        --id $result.id `
        --organization $org `
        --relation-type parent `
        --target-id 2921611 `
        --output none

    Write-Output ("Created and linked: " + $result.id)
}

foreach ($id in $createdIds) {
    az boards work-item show --id $id --organization $org --output json > "$env:TEMP\verify_lmri_prod_$id.json"
    $verified = Get-Content "$env:TEMP\verify_lmri_prod_$id.json" -Raw | ConvertFrom-Json
    Write-Output ("Verified: " + $verified.id + " | " + $verified.fields.'System.Title' + " | Parent=" + $verified.fields.'System.Parent' + " | Tags=" + $verified.fields.'System.Tags')
}
