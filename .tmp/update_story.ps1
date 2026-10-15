$org = "https://dev.azure.com/AmericanAirlines"
$id = 3084151

$desc = '<div><b>Given</b> the LMRI GraphQL API currently truncates the departure timestamp to date-only format (yyyy-MM-dd, e.g., "2026-08-27")<br><b>When</b> clients query departure details via the LMRI GraphQL API<br><b>Then</b> the ''departureDate'' field in the API response and schema is updated to include both local departure date and time in ''yyyy-MM-ddTHH:mm:ss'' format (e.g., "2026-08-27T17:29:00")<br><b>And</b> the GraphQL schema is updated to explicitly document local airport time and the new format string</div><br><div><b>Context:</b> Currently in the API, we are truncating the date time field to only show the date in the response. (yyyy-MM-dd) We want to include the time as well to give clients a precise time and allow clients to calculate accurate relative durations, should they need to. Today response "departureDate": "2026-08-27". Tomo''s response "departureDate": "2026-08-27T17:29:00".</div><br><div><b>Open Design Question:</b><br>The <code>departureDate</code> field will contain both date and time values after this change. Prior to implementation, confirm whether:<br>- <code>departureDate</code> remains the field name, or<br>- a new <code>departureDateTime</code> field should be introduced.<br>Any approved naming decision must be reflected in the GraphQL schema documentation.</div>'

$ac = '<div><b>Scenario 1: Update response format to include local departure time</b><br><b>Given</b> a client requests flight departure details from the LMRI GraphQL API<br><b>When</b> the response payload is generated<br><b>Then</b> the ''departureDate'' field is formatted as ''yyyy-MM-ddTHH:mm:ss'' (e.g., "2026-08-27T17:29:00")<br><b>And</b> the timestamp explicitly represents local departure airport time and is not converted to UTC.</div><br><div><b>Scenario 2: Update GraphQL schema definition and documentation</b><br><b>Given</b> the LMRI GraphQL API schema definition<br><b>When</b> the ''departureDate'' field definition and schema documentation are updated<br><b>Then</b> the schema documentation explicitly states ''departureDate'' represents local departure airport time<br><b>And</b> the schema specifies the format string as ''yyyy-MM-ddTHH:mm:ss''.</div><br><div><b>Scenario 3: Consumer impact assessment completed</b><br><b>Given</b> departureDate is changing from yyyy-MM-dd to yyyy-MM-ddTHH:mm:ss<br><b>When</b> downstream consumers are reviewed<br><b>Then</b> consumers of departureDate are identified<br><b>And</b> any parsing impacts are documented<br><b>And</b> required communications or remediation activities are completed prior to production deployment.</div>'

az boards work-item update `
    --id $id `
    --organization $org `
    --fields "System.Description=$desc" `
             "Microsoft.VSTS.Common.AcceptanceCriteria=$ac" `
    --output json | Out-Null

Write-Host "Successfully updated Work Item $id"
