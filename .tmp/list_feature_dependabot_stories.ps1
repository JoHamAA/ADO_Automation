$ErrorActionPreference = 'Stop'

$org = 'https://dev.azure.com/AmericanAirlines'
$project = 'PassengerDataHub'
$featureId = 2934796

$wiql = "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = '$project' AND [System.Parent] = $featureId ORDER BY [System.Id] ASC"
$ids = @(az boards query --organization $org --project $project --wiql $wiql --query '[].id' --output tsv)

$rows = foreach ($id in $ids) {
    $item = az boards work-item show `
        --id $id `
        --organization $org `
        --fields 'System.Title,System.WorkItemType,System.State,System.Parent' `
        --expand None `
        --output json | ConvertFrom-Json

    [pscustomobject]@{
        Id = [int]$item.id
        Title = $item.fields.'System.Title'
        Type = $item.fields.'System.WorkItemType'
        State = $item.fields.'System.State'
        Parent = $item.fields.'System.Parent'
    }
}

$dependabot = @(
    $rows |
        Where-Object { $_.Type -eq 'User Story' -and $_.Title -match 'Dependabot' } |
        Sort-Object Id
)

Write-Output "Total direct children under Feature ${featureId}: $($rows.Count)"
Write-Output "Dependabot User Stories found by hydrated title: $($dependabot.Count)"

foreach ($row in $dependabot) {
    Write-Output ("{0} | {1} | State={2} | Parent={3}" -f $row.Id, $row.Title, $row.State, $row.Parent)
}