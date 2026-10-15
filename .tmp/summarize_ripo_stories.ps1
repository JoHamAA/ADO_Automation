$data = @(Get-Content "$env:TEMP\all_ripo_vulnerability_stories.json" -Raw | ConvertFrom-Json)
Write-Output ("Count: " + $data.Count)
foreach ($item in $data) {
    Write-Output ("{0} | {1} | Parent={2} | Rank={3}" -f $item.id, $item.fields.'System.Title', $item.fields.'System.Parent', $item.fields.'Microsoft.VSTS.Common.StackRank')
}
