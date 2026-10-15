$wiql = "SELECT [System.Id], [System.Title], [System.Parent], [Microsoft.VSTS.Common.StackRank] FROM WorkItems WHERE [System.TeamProject] = 'PassengerDataHub' AND [System.WorkItemType] = 'User Story' AND [System.Title] CONTAINS 'Remediate Vulnerabilities' ORDER BY [System.Id] ASC"
$result = az boards query --organization https://dev.azure.com/AmericanAirlines --project PassengerDataHub --wiql $wiql --output json | ConvertFrom-Json
Write-Output ("Count: " + @($result).Count)
foreach ($item in @($result)) {
    Write-Output ("{0} | {1} | Parent={2} | Rank={3}" -f $item.id, $item.fields.'System.Title', $item.fields.'System.Parent', $item.fields.'Microsoft.VSTS.Common.StackRank')
}
