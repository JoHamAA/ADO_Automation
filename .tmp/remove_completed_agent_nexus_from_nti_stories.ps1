$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"
$parentId = 3054458
$stories = @(
    @{ Id = 3190102; Application = "ch-pnr-details"; CompletedId = 3087658 },
    @{ Id = 3190109; Application = "ch-backend-kbyg-email"; CompletedId = 3087628 },
    @{ Id = 3190111; Application = "ch-backend-kbyg-term-info"; CompletedId = 3087631 }
)

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

$acceptancePattern = [regex]::new(
    '\s*<br>\s*<div><b>Confirm completed Agent Nexus onboarding remains active</b>.*?</div>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)

foreach ($story in $stories) {
    $storyId = [int]$story.Id
    $completedId = [int]$story.CompletedId
    $descriptionPattern = [regex]::new(
        "Agent Nexus onboarding is already complete under <a href=`"[^`"]+`">work item $completedId</a>; this story must confirm that onboarding remains active for the NTI changes rather than duplicate completed work\. Reference: <a href=`"[^`"]+`">Agent Nexus Onboarding Instructions</a>\."
    )

    $before = az boards work-item show --id $storyId --organization $org --expand all --output json | ConvertFrom-Json
    if ($before.fields.'System.TeamProject' -ne $project) { throw "PREFLIGHT id=$storyId is not in $project." }
    if ($before.fields.'System.WorkItemType' -ne "User Story") { throw "PREFLIGHT id=$storyId is not a User Story." }
    if ((Get-ParentId -WorkItem $before) -ne $parentId) { throw "PREFLIGHT id=$storyId does not belong to parent $parentId." }

    $currentDescription = [string]$before.fields.'System.Description'
    $currentAcceptance = [string]$before.fields.'Microsoft.VSTS.Common.AcceptanceCriteria'
    if ($descriptionPattern.Matches($currentDescription).Count -ne 1) { throw "PREFLIGHT id=$storyId does not have exactly one completed Agent Nexus note." }
    if ($acceptancePattern.Matches($currentAcceptance).Count -ne 1) { throw "PREFLIGHT id=$storyId does not have exactly one completed Agent Nexus criterion." }

    $updatedDescription = $descriptionPattern.Replace($currentDescription, '', 1)
    $updatedAcceptance = $acceptancePattern.Replace($currentAcceptance, '', 1)
    Write-Host "PREFLIGHT id=$storyId application=$($story.Application) removeAgentNexus=true"

    $updated = az boards work-item update --id $storyId --organization $org --fields "System.Description=$updatedDescription" "Microsoft.VSTS.Common.AcceptanceCriteria=$updatedAcceptance" --output json | ConvertFrom-Json
    if (-not $updated.id) { throw "UPDATE failed for work item $storyId." }
    Write-Host "UPDATE id=$storyId agentNexusRemoved=true"

    $verified = az boards work-item show --id $storyId --organization $org --expand all --output json | ConvertFrom-Json
    $verifiedDescription = [string]$verified.fields.'System.Description'
    $verifiedAcceptance = [string]$verified.fields.'Microsoft.VSTS.Common.AcceptanceCriteria'
    $checks = @(
        ($verified.id -eq $storyId),
        ($verified.fields.'System.Title' -eq $before.fields.'System.Title'),
        ($verified.fields.'System.WorkItemType' -eq $before.fields.'System.WorkItemType'),
        ($verified.fields.'System.State' -eq $before.fields.'System.State'),
        ($verified.fields.'System.AreaPath' -eq $before.fields.'System.AreaPath'),
        ($verified.fields.'System.IterationPath' -eq $before.fields.'System.IterationPath'),
        ($verified.fields.'System.Tags' -eq $before.fields.'System.Tags'),
        ([double]$verified.fields.'Microsoft.VSTS.Common.StackRank' -eq [double]$before.fields.'Microsoft.VSTS.Common.StackRank'),
        ((Get-ParentId -WorkItem $verified) -eq $parentId),
        ((Normalize-RichText $verifiedDescription) -eq (Normalize-RichText $updatedDescription)),
        ((Normalize-RichText $verifiedAcceptance) -eq (Normalize-RichText $updatedAcceptance)),
        (-not $verifiedDescription.Contains('Agent Nexus')),
        (-not $verifiedAcceptance.Contains('Agent Nexus')),
        (-not $verifiedDescription.Contains([string]$completedId)),
        (-not $verifiedAcceptance.Contains([string]$completedId)),
        ($verifiedDescription.Contains('Silver Bird')),
        ($verifiedDescription.Contains('Technical implementation location')),
        (([regex]::Matches($verifiedAcceptance, '<div><b>')).Count -eq 5)
    )
    if ($checks -contains $false) { throw "VERIFY failed for work item $storyId." }
    Write-Host "VERIFY id=$storyId url=$org/$project/_workitems/edit/$storyId agentNexus=false acceptanceCriteria=5 unchangedFields=true"
}