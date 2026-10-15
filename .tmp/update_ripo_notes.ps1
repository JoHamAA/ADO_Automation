$ErrorActionPreference = "Stop"
$org = "https://dev.azure.com/AmericanAirlines"
$note = 'Agent Nexus Onboarding Instructions: <a href="https://github.com/AAInternal/aa-commercial-agent-skills#onboarding-a-team-consumer-quickstart">https://github.com/AAInternal/aa-commercial-agent-skills#onboarding-a-team-consumer-quickstart</a>'
$raw = Get-Content "$env:TEMP\ripo_notes_latest.json" -Raw
$data = ConvertFrom-Json $raw
if ($data.Count -ne 31) { throw "Expected 31 vulnerability stories, found $($data.Count)." }

foreach ($item in $data) {
    az boards work-item update `
        --id $item.id `
        --organization $org `
        --fields "AAIT.Notes=$note" `
        --output none
    Write-Output ("Updated notes: " + $item.id)
}

foreach ($item in $data) {
    az boards work-item show --id $item.id --organization $org --output json > "$env:TEMP\verify_ripo_notes_$($item.id).json"
    $verified = Get-Content "$env:TEMP\verify_ripo_notes_$($item.id).json" -Raw | ConvertFrom-Json
    if ($verified.fields.'AAIT.Notes' -notlike '*Agent Nexus Onboarding Instructions*') {
        throw "Notes verification failed for $($item.id)."
    }
}
Write-Output "Verified notes on $($data.Count) stories."
