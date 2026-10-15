$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"
$iteration = "PassengerDataHub"
$title = "PaxHub - OPS - Internal Microgateway - Renew custeventservices.aa.com PROD Certificate (Expires Nov 30 2026)"
$description = '<div><b>Given</b> the production TLS certificate for custeventservices.aa.com expires on 30 Nov 2026 at 23:59:59 GMT<br><b>When</b> PaxHub prepares the internal-mgw (Internal Microgateway) certificate rotation during November<br><b>Then</b> the certificate is renewed and installed in the correct production certificate store before expiration<br><b>And</b> the custom domain used by RIPA for the VCR Retrieval API continues to work with the renewed certificate</div><br><div><b>Context:</b> The production certificate for custeventservices.aa.com (CN and DNS SAN) is used by PaxHub internal-mgw for the RIPA VCR Retrieval API custom domain. Confirm the owning application, KeyFactor metadata, Locations and CertStores, and service bindings before renewal. Coordinate the change for November and complete it before the 30 Nov 2026 23:59:59 GMT expiration; do not assign a sprint until one is explicitly planned. Renewing in KeyFactor alone is insufficient: install and activate the certificate on the operational Microgateway, verify live traffic serves the new certificate, and retire or revoke the old certificate only when confirmed non-operational and approved. Base operational details on the certificate expiration notice received 1 Oct 2026. This is a new renewal cycle, separate from the accepted June 2026 certificate renewal.</div>'
$criteria = '<div><b>Confirm certificate ownership and deployment targets</b><br><b>Given</b> the custeventservices.aa.com production certificate is approaching expiry<br><b>When</b> the team reviews the KeyFactor record and internal-mgw deployment<br><b>Then</b> application ownership, CN and SAN, Locations, CertStores, custom domain binding, and RIPA VCR Retrieval API dependency are confirmed<br><b>And</b> any incorrect metadata, access gaps, or additional consumers are documented and resolved before rotation.</div><br><div><b>Renew and activate before the November deadline</b><br><b>Given</b> the production certificate expires on 30 Nov 2026 at 23:59:59 GMT<br><b>When</b> the renewal is approved and scheduled during November<br><b>Then</b> a valid replacement certificate is obtained via KeyFactor and installed and activated in the correct PaxHub internal-mgw production certificate store before expiry<br><b>And</b> the deployed certificate covers custeventservices.aa.com and its private key is handled only through approved secure channels.</div><br><div><b>Verify the live custom domain and recover from failures</b><br><b>Given</b> internal-mgw serves RIPA VCR Retrieval API traffic through the custom domain<br><b>When</b> the replacement certificate is activated<br><b>Then</b> a live TLS handshake confirms the expected renewed certificate and representative RIPA VCR Retrieval API requests succeed without certificate or consumer errors<br><b>And</b> monitoring and a rollback plan address failed deployment, wrong bindings, or traffic regressions without exposing credentials or private keys.</div><br><div><b>Record evidence and retire the old certificate safely</b><br><b>Given</b> the replacement certificate is serving live production requests<br><b>When</b> the renewal is closed out<br><b>Then</b> the renewal, deployment, verification evidence, updated KeyFactor metadata, support instructions, and any impacted consumers are documented<br><b>And</b> the old certificate is revoked or removed only after confirming it is non-operational and no longer used by other mapped services.</div>'

function Invoke-AzJson {
    param([string[]]$Arguments)
    $result = & az @Arguments | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw "az command failed: $($Arguments[0..2] -join ' ')" }
    return $result
}

$duplicateWiql = "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.Title] = '$($title.Replace("'", "''"))'"
$duplicates = @(Invoke-AzJson -Arguments @("boards", "query", "--organization", $org, "--project", $project, "--wiql", $duplicateWiql, "--output", "json") | Where-Object { $_.id })
if ($duplicates.Count -gt 0) { Write-Host "DUPLICATE duplicate_exists id=$($duplicates[0].id) url=$org/$project/_workitems/edit/$($duplicates[0].id)"; exit 10 }
Write-Host "DUPLICATE none title=$title"

$rankWiql = "SELECT [System.Id], [Microsoft.VSTS.Common.StackRank] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.IterationPath] UNDER '$iteration' ORDER BY [Microsoft.VSTS.Common.StackRank] ASC"
$rankItems = @(Invoke-AzJson -Arguments @("boards", "query", "--organization", $org, "--project", $project, "--wiql", $rankWiql, "--output", "json"))
$rankValues = @($rankItems | ForEach-Object { $_.fields.'Microsoft.VSTS.Common.StackRank' } | Where-Object { $null -ne $_ -and "$_" -ne "" })
$priorMinRank = $null
$parsedRank = 0.0
if ($rankValues.Count -gt 0 -and [double]::TryParse("$($rankValues[0])", [ref]$parsedRank)) { $priorMinRank = $parsedRank }
$stackRank = if ($null -eq $priorMinRank) { -1000000 } else { $priorMinRank - 1000 }
Write-Host "RANK priorMin=$priorMinRank new=$stackRank"

$created = Invoke-AzJson -Arguments @("boards", "work-item", "create", "--organization", $org, "--project", $project, "--type", "User Story", "--title", $title, "--area", $project, "--iteration", $iteration, "--fields", "System.Description=$description", "Microsoft.VSTS.Common.AcceptanceCriteria=$criteria", "Microsoft.VSTS.Scheduling.StoryPoints=0", "Microsoft.VSTS.Common.Priority=2", "AAIT.Ready=Yes", "AAIT.WorkType=4. Software / UX", "System.State=Backlog", "System.Tags=AI-StoryWriting", "Microsoft.VSTS.Common.StackRank=$stackRank", "--output", "json")
if (-not $created.id) { throw "CREATE missing ID; query exact title before retry: $title" }
Write-Host "CREATE id=$($created.id) title=$title"

$verified = Invoke-AzJson -Arguments @("boards", "work-item", "show", "--id", "$($created.id)", "--organization", $org, "--expand", "all", "--output", "json")
$checks = @(
    ($verified.id -eq $created.id), ($verified.fields.'System.Title' -eq $title),
    ($verified.fields.'System.WorkItemType' -eq "User Story"), ($verified.fields.'System.State' -eq "Backlog"),
    ($verified.fields.'System.AreaPath' -eq $project), ($verified.fields.'System.IterationPath' -eq $iteration),
    ($verified.fields.'System.Tags' -like "*AI-StoryWriting*"),
    (@($verified.relations | Where-Object { $_.rel -eq "System.LinkTypes.Hierarchy-Reverse" }).Count -eq 0),
    ($verified.fields.'System.Description' -eq $description),
    ($verified.fields.'Microsoft.VSTS.Common.AcceptanceCriteria' -eq $criteria),
    ([double]$verified.fields.'Microsoft.VSTS.Common.StackRank' -eq $stackRank)
)
if ($null -ne $priorMinRank) { $checks += ([double]$verified.fields.'Microsoft.VSTS.Common.StackRank' -lt $priorMinRank) }
if ($checks -contains $false) { throw "VERIFY failed for id=$($created.id); inspect exact ID before reporting." }
Write-Host "VERIFY id=$($created.id) url=$org/$project/_workitems/edit/$($created.id) title=$title type=User Story state=Backlog area=$project iteration=$iteration tags=$($verified.fields.'System.Tags') stackRank=$stackRank parent=none description=true acceptanceCriteria=true"