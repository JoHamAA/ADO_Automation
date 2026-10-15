$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
$wb = $excel.Workbooks.Open("c:\MCP_Story_Automation\.github\PAX_Backlog.xls")
$sheet = $wb.Sheets.Item(1)

# Save as CSV
$csvPath = "c:\MCP_Story_Automation\.github\PAX_Backlog.csv"
if (Test-Path $csvPath) { Remove-Item $csvPath }
$wb.SaveAs($csvPath, 6) # 6 = xlCSV

$wb.Close($false)
$excel.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
Write-Host "Exported to $csvPath"
