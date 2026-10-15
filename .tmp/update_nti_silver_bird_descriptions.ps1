$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"
$parentId = 3054458
$storyIds = @(3190102, 3190103, 3190104, 3190106, 3190107, 3190108, 3190109, 3190111, 3190112, 3190114)
$contextPattern = [regex]::new('<div><b>Context:</b>\s*')
$clarification = 'The Sabre tier code is TBD. Once finalized, PaxHub will translate that code to <b>Silver Bird</b>, the customer-facing name for the New Tier Initiative''s new pre-Gold tier. '

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

foreach ($storyId in $storyIds) {
    $before = az boards work-item show --id $storyId --organization $org --expand all --output json | ConvertFrom-Json
    if ($before.fields.'System.TeamProject' -ne $project) { throw "PREFLIGHT id=$storyId is not in $project." }
    if ($before.fields.'System.WorkItemType' -ne "User Story") { throw "PREFLIGHT id=$storyId is not a User Story." }
    if ((Get-ParentId -WorkItem $before) -ne $parentId) { throw "PREFLIGHT id=$storyId does not belong to parent $parentId." }

    $currentDescription = [string]$before.fields.'System.Description'
    if ($currentDescription.Contains('Silver Bird')) { throw "PREFLIGHT id=$storyId already contains Silver Bird." }
    if ($contextPattern.Matches($currentDescription).Count -ne 1) { throw "PREFLIGHT id=$storyId does not have exactly one Context block." }

    $updatedDescription = $contextPattern.Replace(
        $currentDescription,
        "<div><b>Context:</b> $clarification",
        1
    )
    Write-Host "PREFLIGHT id=$storyId title=$($before.fields.'System.Title') descriptionChange=true"

    $updated = az boards work-item update --id $storyId --organization $org --fields "System.Description=$updatedDescription" --output json | ConvertFrom-Json
    if (-not $updated.id) { throw "UPDATE failed for work item $storyId." }
    Write-Host "UPDATE id=$storyId description=true"

    $verified = az boards work-item show --id $storyId --organization $org --expand all --output json | ConvertFrom-Json
    $verifiedDescription = [string]$verified.fields.'System.Description'
    $checks = @(
        ($verified.id -eq $storyId),
        ($verified.fields.'System.Title' -eq $before.fields.'System.Title'),
        ($verified.fields.'System.WorkItemType' -eq $before.fields.'System.WorkItemType'),
        ($verified.fields.'System.State' -eq $before.fields.'System.State'),
        ($verified.fields.'System.AreaPath' -eq $before.fields.'System.AreaPath'),
        ($verified.fields.'System.IterationPath' -eq $before.fields.'System.IterationPath'),
        ($verified.fields.'System.Tags' -eq $before.fields.'System.Tags'),
        ($verified.fields.'Microsoft.VSTS.Common.AcceptanceCriteria' -eq $before.fields.'Microsoft.VSTS.Common.AcceptanceCriteria'),
        ([double]$verified.fields.'Microsoft.VSTS.Common.StackRank' -eq [double]$before.fields.'Microsoft.VSTS.Common.StackRank'),
        ((Get-ParentId -WorkItem $verified) -eq $parentId),
        ((Normalize-RichText $verifiedDescription) -eq (Normalize-RichText $updatedDescription)),
        ($verifiedDescription.Contains('The Sabre tier code is TBD.')),
        ($verifiedDescription.Contains('Silver Bird')),
        ($verifiedDescription.Contains('new pre-Gold tier'))
    )
    if ($checks -contains $false) { throw "VERIFY failed for work item $storyId." }
    Write-Host "VERIFY id=$storyId url=$org/$project/_workitems/edit/$storyId description=true unchangedFields=true"
}