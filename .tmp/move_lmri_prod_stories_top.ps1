$data = Get-Content "$env:TEMP\pax_story_stackranks.json" -Raw | ConvertFrom-Json
$ranked = @($data | Where-Object { $null -ne $_.fields.'Microsoft.VSTS.Common.StackRank' })
if ($ranked.Count -eq 0) { throw "No existing User Story stack rank was returned." }
$minimumRank = [double]$ranked[0].fields.'Microsoft.VSTS.Common.StackRank'
$rankFirst = $minimumRank - 1000
$rankSecond = $minimumRank - 999

az boards work-item update --id 3087522 --organization https://dev.azure.com/AmericanAirlines --fields "Microsoft.VSTS.Common.StackRank=$rankFirst" --output none
az boards work-item update --id 3087523 --organization https://dev.azure.com/AmericanAirlines --fields "Microsoft.VSTS.Common.StackRank=$rankSecond" --output none

Write-Output ("Minimum existing rank: $minimumRank")
Write-Output ("3087522 assigned rank: $rankFirst")
Write-Output ("3087523 assigned rank: $rankSecond")
