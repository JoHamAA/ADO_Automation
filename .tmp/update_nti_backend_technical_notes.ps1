$ErrorActionPreference = "Stop"

$org = "https://dev.azure.com/AmericanAirlines"
$project = "PassengerDataHub"
$parentId = 3054458

$updates = @(
    @{
        Id = 3190102
        Application = "ch-pnr-details"
        Location = "the tier map in PNRDetailsTransformer.java"
        Link = "https://github.com/AAInternal/ch-pnr-details/blob/2356104ae53e34931e671f5bab0e0e27c98bd7d4/src/main/java/com/aa/custhub/pnrdetails/transformer/PNRDetailsTransformer.java#L62"
    },
    @{
        Id = 3190103
        Application = "ch-passenger-manifest"
        Location = "application.yaml and the corresponding map in PropertyFileConfig.java"
        Link = "https://github.com/AAInternal/ch-passenger-manifest/blob/ca5f168ed50105985f6f29023b51a9a82e3b8bd8/src/main/resources/application.yaml#L31"
    },
    @{
        Id = 3190104
        Application = "ch-customer-pnr"
        Location = "EdpdOrdFrqTvrDAO.findFrequentTravelerByPnrIdAndCreateDateWithCustomSelect"
        Link = $null
    },
    @{
        Id = 3190106
        Application = "ch-backend-oms-flight-stats"
        Location = "QueryConstants.OMS_TIER_QUERY"
        Link = $null
    },
    @{
        Id = 3190107
        Application = "ch-backend-oms-night-flight-stats"
        Location = "QueryConstants.OMS_TIER_QUERY"
        Link = "https://github.com/AAInternal/ch-backend-oms-night-flight-stats/blob/ffb3696b7c7fc8aec71c6fe3c43e0c5af9b47227/src/main/java/com/aa/custhub/oms/common/QueryConstants.java#L28"
    },
    @{
        Id = 3190108
        Application = "ch-backend-pdp-email"
        Location = "SQLConstants.PDPEMAIL_SQL1"
        Link = $null
    },
    @{
        Id = 3190109
        Application = "ch-backend-kbyg-email"
        Location = "SQLConstants.KBYG_HANDOFF_SQL"
        Link = "https://github.com/AAInternal/ch-backend-kbyg-email/blob/0fa473dca62d9c288775f18ef33fef98055b0748/src/main/java/com/aa/custhub/kbyg/constants/SQLConstants.java#L5"
    },
    @{
        Id = 3190111
        Application = "ch-backend-kbyg-term-info"
        Location = "SQLConstants.TERMINAL_INFO_SQL"
        Link = "https://github.com/AAInternal/ch-backend-kbyg-term-info/blob/61e4ee268043908221d074ffa52f206fd4bd6510/src/main/java/com/aa/custhub/kbyg/shared/SQLConstants.java#L4"
    },
    @{
        Id = 3190112
        Application = "ch-backend-international-outbound"
        Location = "SQLConstant.INTL_OUTBOUND_SQL"
        Link = "https://github.com/AAInternal/ch-backend-international-outbound/blob/develop/src/main/java/com/aa/custhub/ioa/shared/SQLConstant.java"
    }
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

foreach ($change in $updates) {
    $storyId = [int]$change.Id
    $before = az boards work-item show --id $storyId --organization $org --expand all --output json | ConvertFrom-Json
    if ($before.fields.'System.TeamProject' -ne $project) { throw "PREFLIGHT id=$storyId is not in $project." }
    if ($before.fields.'System.WorkItemType' -ne "User Story") { throw "PREFLIGHT id=$storyId is not a User Story." }
    if ((Get-ParentId -WorkItem $before) -ne $parentId) { throw "PREFLIGHT id=$storyId does not belong to parent $parentId." }

    $currentDescription = [string]$before.fields.'System.Description'
    $currentAcceptance = [string]$before.fields.'Microsoft.VSTS.Common.AcceptanceCriteria'
    if ($currentDescription.Contains('Technical implementation location')) { throw "PREFLIGHT id=$storyId already has technical notes." }
    if (([regex]::Matches($currentAcceptance, '<div><b>')).Count -ne 5) { throw "PREFLIGHT id=$storyId does not have five existing acceptance criteria." }

    if ($null -ne $change.Link) {
        $locationReference = "<a href=`"$($change.Link)`">$($change.Location)</a>"
    } else {
        $locationReference = $change.Location
    }

    $technicalContext = "<br><div><b>Tier data flow reference:</b> Sabre supplies the tier as wVITType in the frequentTraveller section. PaxHub stores tier information as the numeric PGM_FRQ_TVR_GRP_NR_CD value in the EDPD_ORD_FRQ_TVR FRQ table. The TBD Sabre code must be mapped to Silver Bird through application properties or the existing transformation query logic.</div><br><div><b>Technical implementation location:</b> Update $locationReference for $($change.Application).</div>"
    $technicalCriterion = "<br><div><b>Implement and test the Silver Bird mapping at the identified code location</b><br><b>Given</b> Sabre sends the TBD Silver Bird tier code as wVITType in frequentTraveller and PaxHub persists or returns the mapped PGM_FRQ_TVR_GRP_NR_CD value<br><b>When</b> the New Tier Initiative change is implemented for $($change.Application)<br><b>Then</b> $locationReference is updated so the approved Sabre code translates to Silver Bird through the application's existing mapping or query path<br><b>And</b> automated tests cover Silver Bird, existing tiers, missing values, and unknown tier codes without changing current tier behavior.</div>"

    $updatedDescription = $currentDescription + $technicalContext
    $updatedAcceptance = $currentAcceptance + $technicalCriterion
    Write-Host "PREFLIGHT id=$storyId application=$($change.Application) description=true acceptanceCriteria=true"

    $updated = az boards work-item update --id $storyId --organization $org --fields "System.Description=$updatedDescription" "Microsoft.VSTS.Common.AcceptanceCriteria=$updatedAcceptance" --output json | ConvertFrom-Json
    if (-not $updated.id) { throw "UPDATE failed for work item $storyId." }
    Write-Host "UPDATE id=$storyId technicalNotes=true acceptanceCriteria=true"

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
        ($verifiedDescription.Contains('wVITType')),
        ($verifiedDescription.Contains('PGM_FRQ_TVR_GRP_NR_CD')),
        ($verifiedDescription.Contains($change.Location)),
        ($verifiedAcceptance.Contains($change.Location)),
        (([regex]::Matches($verifiedAcceptance, '<div><b>')).Count -eq 6)
    )
    if ($null -ne $change.Link) {
        $checks += $verifiedDescription.Contains($change.Link)
        $checks += $verifiedAcceptance.Contains($change.Link)
    }
    if ($checks -contains $false) { throw "VERIFY failed for work item $storyId." }
    Write-Host "VERIFY id=$storyId url=$org/$project/_workitems/edit/$storyId description=true acceptanceCriteria=6 unchangedFields=true"
}