$ErrorActionPreference = 'Stop'

$org = 'https://dev.azure.com/AmericanAirlines'
$project = 'PassengerDataHub'
$featureId = 2934778
$title = 'test #09'
$context = 'testing how well you create stories with updated instructions'

$az = 'az'
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
  $candidates = @(
    'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd',
    'C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'
  )
  $az = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $az) {
    throw 'Azure CLI not found'
  }
}

& $az devops configure --defaults organization=$org project=$project | Out-Null

$dupWiql = "Select [System.Id] From WorkItems Where [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.Parent] = $featureId AND [System.Title] = '$title'"
$dupRows = @(& $az boards query --wiql $dupWiql --org $org --project $project --output json | ConvertFrom-Json)
if ($dupRows.Count -gt 0) {
  [pscustomobject]@{
    status = 'duplicate_exists'
    id = [int]$dupRows[0].id
    title = $title
    parentFeature = $featureId
    url = "$org/$project/_workitems/edit/$($dupRows[0].id)"
  } | ConvertTo-Json -Depth 5
  exit 0
}

$feature = & $az boards work-item show --id $featureId --org $org --output json | ConvertFrom-Json
$featureTags = [string]$feature.fields.'System.Tags'

$rankWiql = "Select [System.Id] From WorkItems Where [System.TeamProject] = '$project' AND [System.WorkItemType] = 'User Story' AND [System.State] <> 'Removed' ORDER BY [Microsoft.VSTS.Common.StackRank] ASC"
$rankRows = @(& $az boards query --wiql $rankWiql --org $org --project $project --output json | ConvertFrom-Json)
if ($rankRows.Count -eq 0) {
  $newRank = 1
} else {
  $topId = [int]$rankRows[0].id
  $top = & $az boards work-item show --id $topId --org $org --output json | ConvertFrom-Json
  $topRankRaw = [string]$top.fields.'Microsoft.VSTS.Common.StackRank'
  if ([string]::IsNullOrWhiteSpace($topRankRaw)) {
    $newRank = 1
  } else {
    $newRank = ([double]$topRankRaw) - 1000
  }
}

$desc = '<b>Given</b> a PassengerDataHub user needs a new story under the selected feature<br><b>When</b> story creation is requested<br><b>Then</b> the story is created with required defaults, tags, and link<br><b>Context</b>: ' + $context
$ac = '<b>Scenario #:</b> Story creation with defaults<br><b>Given</b> a valid feature and project<br><b>When</b> the story is created<br><b>Then</b> required fields, inherited tags, and parent relation are present'

$created = & $az boards work-item create --org $org --project $project --type 'User Story' --title $title --area PassengerDataHub --iteration PassengerDataHub --fields "Microsoft.VSTS.Scheduling.StoryPoints=0" "AAIT.WorkType=4. Software / UX" "Microsoft.VSTS.Common.Priority=2" "AAIT.Ready=Yes" "Microsoft.VSTS.Common.StackRank=$newRank" "System.Description=$desc" "Microsoft.VSTS.Common.AcceptanceCriteria=$ac" "System.Tags=$featureTags" --output json | ConvertFrom-Json
$newId = [int]$created.id

& $az boards work-item relation add --id $newId --relation-type parent --target-id $featureId --org $org --output none

$verify = & $az boards work-item show --id $newId --org $org --output json | ConvertFrom-Json
[pscustomobject]@{
  status = 'created'
  id = $verify.id
  title = $verify.fields.'System.Title'
  parentFeature = $verify.fields.'System.Parent'
  tags = $verify.fields.'System.Tags'
  stackRank = $verify.fields.'Microsoft.VSTS.Common.StackRank'
  url = "$org/$project/_workitems/edit/$($verify.id)"
} | ConvertTo-Json -Depth 5
