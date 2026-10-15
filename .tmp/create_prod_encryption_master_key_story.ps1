$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"
$parentId = 2951225
$sourceStoryId = 3144027
$title = "PaxHub - Migration to MongoDB - ENCRYPTION - Setup Encryption Master Key in PROD Key Vaults"
$iteration = "PassengerDataHub"

$description = '<div><b>Given</b> MongoDB field-level encryption is configured in the STAGE environment<br><b>When</b> the same encryption foundation is needed for the PROD environment<br><b>Then</b> the encryption master key is set up in the PROD Key Vaults<br><b>And</b> the PROD Mongo PNR Processor SPII Function App and PNR Graph API can access the key required to encrypt and decrypt government document fields</div><br><div><b>Context:</b> This story follows the STAGE encryption setup in work item 3144027 and establishes the equivalent production configuration. PROD PNR Graph API resources include ct-p-zeaus-pnr-gql-ap, ct-p-zeaus-pnr-gql-ap/DEPLOY, ct-p-zweus-pnr-gql-ap, and ct-p-zweus-pnr-gql-ap/DEPLOY. The SPII Processor PROD Function App has not been created yet; its required network path, managed identity, and Key Vault permissions must be documented and applied after the resource is available.</div>'

$acceptanceCriteria = '<div><b>Set up the encryption master key in PROD Key Vaults</b><br><b>Given</b> the approved STAGE MongoDB encryption setup is available as the reference pattern<br><b>When</b> the PROD Key Vault configuration is implemented<br><b>Then</b> the required encryption master key is created or configured in the appropriate PROD Key Vaults<br><b>And</b> key naming, versioning, ownership, rotation, recovery, and environment-specific configuration are documented.</div><br><div><b>Enable PROD network access for encryption consumers</b><br><b>Given</b> the PROD PNR Graph API resources and future SPII Processor Function App require Key Vault access<br><b>When</b> network rules and private or service access paths are configured<br><b>Then</b> Key Vault reachability is validated for ct-p-zeaus-pnr-gql-ap, ct-p-zeaus-pnr-gql-ap/DEPLOY, ct-p-zweus-pnr-gql-ap, and ct-p-zweus-pnr-gql-ap/DEPLOY<br><b>And</b> the required network configuration for the SPII Processor PROD Function App is documented and validated after that Function App is created.</div><br><div><b>Grant least-privilege PROD key permissions</b><br><b>Given</b> the SPII Processor encrypts government document fields and the PNR Graph API decrypts them<br><b>When</b> managed identities or service principals are granted PROD Key Vault access<br><b>Then</b> each existing PNR Graph API resource receives only the permissions required to decrypt authorized fields<br><b>And</b> the SPII Processor PROD Function App receives only the required encryption permissions after its managed identity is available.</div><br><div><b>Validate PROD encryption behavior and failure handling</b><br><b>Given</b> the master key, network access, and permissions are configured for available PROD consumers<br><b>When</b> representative government document data is processed and retrieved through the authorized production paths<br><b>Then</b> sensitive fields are encrypted before persistence and decrypted only for authorized consumers without unacceptable latency or service instability<br><b>And</b> missing keys, denied network access, invalid configuration, and insufficient permissions produce actionable errors and monitoring signals without exposing sensitive values.</div>'

function Get-ParentId {
    param($WorkItem)
    $relation = @($WorkItem.relations | Where-Object { $_.rel -eq "System.LinkTypes.Hierarchy-Reverse" }) | Select-Object -First 1
    if (-not $relation) { return $null }
    return [int]($relation.url.Split('/')[-1])
}

function Normalize-RichText {
    param([string]$Value)
    return $Value -replace '\s+</div>', '</div>'
}

$parent = az boards work-item show --id $parentId --organization $org --expand all --output json | ConvertFrom-Json
if ($parent.fields.'System.TeamProject' -ne $project) { throw "PARENT $parentId is not in $project." }
if ($parent.fields.'System.WorkItemType' -ne "Feature") { throw "PARENT $parentId is not a Feature." }

$area = $parent.fields.'System.AreaPath'
$parentTags = @($parent.fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$tags = @($parentTags + "AI-StoryWriting" | Sort-Object -Unique) -join "; "
Write-Host "PARENT id=$parentId type=Feature area=$area iteration=$iteration tags=$tags source=$sourceStoryId"

$escapedTitle = $title.Replace("'", "''")
$duplicateWiql = "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.Title] = '$escapedTitle'"
$duplicates = @(az boards query --organization $org --project $project --wiql $duplicateWiql --output json | ConvertFrom-Json)
if ($duplicates.Count -gt 0) {
    $duplicateId = $duplicates[0].id
    Write-Host "DUPLICATE duplicate_exists id=$duplicateId url=$org/$project/_workitems/edit/$duplicateId"
    exit 10
}
Write-Host "DUPLICATE none title=$title"

$rankWiql = "SELECT [System.Id], [Microsoft.VSTS.Common.StackRank] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.IterationPath] UNDER '$iteration' ORDER BY [Microsoft.VSTS.Common.StackRank] ASC"
$rankItems = @(az boards query --organization $org --project $project --wiql $rankWiql --output json | ConvertFrom-Json)
$rankValues = @($rankItems | ForEach-Object { $_.fields.'Microsoft.VSTS.Common.StackRank' } | Where-Object { $null -ne $_ })
if ($rankValues.Count -gt 0) {
    $priorMinRank = [double]$rankValues[0]
    $stackRank = $priorMinRank - 1000
    Write-Host "RANK priorMin=$priorMinRank new=$stackRank"
} else {
    $priorMinRank = $null
    $stackRank = -1000000
    Write-Host "RANK priorMin=unavailable fallback=$stackRank"
}

$created = az boards work-item create --organization $org --project $project --type "User Story" --title $title --area $area --iteration $iteration --fields "System.Description=$description" "Microsoft.VSTS.Common.AcceptanceCriteria=$acceptanceCriteria" "Microsoft.VSTS.Scheduling.StoryPoints=0" "Microsoft.VSTS.Common.Priority=2" "AAIT.Ready=Yes" "AAIT.WorkType=4. Software / UX" "System.State=Backlog" "System.Tags=$tags" "Microsoft.VSTS.Common.StackRank=$stackRank" --output json | ConvertFrom-Json
if (-not $created.id) { throw "CREATE failed for $title." }
$createdId = [int]$created.id
Write-Host "CREATE id=$createdId rank=$stackRank title=$title"

az boards work-item relation add --id $createdId --organization $org --relation-type parent --target-id $parentId --output json | Out-Null
Write-Host "LINK child=$createdId parent=$parentId"

$verified = az boards work-item show --id $createdId --organization $org --expand all --output json | ConvertFrom-Json
$verifiedParentId = Get-ParentId -WorkItem $verified
$verifiedTags = @($verified.fields.'System.Tags' -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
$expectedTags = @($tags -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
$checks = @(
    ($verified.id -eq $createdId),
    ($verified.fields.'System.Title' -eq $title),
    ($verified.fields.'System.WorkItemType' -eq "User Story"),
    ($verified.fields.'System.State' -eq "Backlog"),
    ($verified.fields.'System.AreaPath' -eq $area),
    ($verified.fields.'System.IterationPath' -eq $iteration),
    ($null -eq (Compare-Object $expectedTags $verifiedTags)),
    ($verifiedParentId -eq $parentId),
    ((Normalize-RichText $verified.fields.'System.Description') -eq (Normalize-RichText $description)),
    ((Normalize-RichText $verified.fields.'Microsoft.VSTS.Common.AcceptanceCriteria') -eq (Normalize-RichText $acceptanceCriteria)),
    ([double]$verified.fields.'Microsoft.VSTS.Common.StackRank' -eq [double]$stackRank)
)
if ($null -ne $priorMinRank) {
    $checks += ([double]$verified.fields.'Microsoft.VSTS.Common.StackRank' -lt $priorMinRank)
}
if ($checks -contains $false) { throw "VERIFY failed for work item $createdId." }

Write-Host "VERIFY id=$createdId url=$org/$project/_workitems/edit/$createdId title=$($verified.fields.'System.Title') type=$($verified.fields.'System.WorkItemType') state=$($verified.fields.'System.State') area=$($verified.fields.'System.AreaPath') iteration=$($verified.fields.'System.IterationPath') tags=$($verified.fields.'System.Tags') stackRank=$($verified.fields.'Microsoft.VSTS.Common.StackRank') parent=$verifiedParentId description=true acceptanceCriteria=true"