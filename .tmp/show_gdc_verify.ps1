$data = Get-Content "$env:TEMP\pax_dfw_gdc_verify.json" -Raw | ConvertFrom-Json
foreach ($item in $data) {
    $fields = $item.fields
    $assignee = $fields.'System.AssignedTo'.displayName
    Write-Output ("{0} | {1} | {2}" -f $item.id, $assignee, $fields.'System.Tags')
}
