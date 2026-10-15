$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
$wb = $excel.Workbooks.Open("c:\MCP_Story_Automation\.github\PAX_Backlog.xls")
$sheet = $wb.Sheets.Item(1)

$rows = $sheet.UsedRange.Rows.Count
$cols = $sheet.UsedRange.Columns.Count

Write-Host "Total Rows: $rows"
Write-Host "Total Columns: $cols"

$headers = @()
for ($c = 1; $c -le $cols; $c++) {
    $headers += $sheet.Cells.Item(1, $c).Text
}

Write-Host "Headers:" ($headers -join ", ")

# Print first 3 rows
for ($r = 2; $r -le [Math]::Min(5, $rows); $r++) {
    Write-Host "--- Row $r ---"
    for ($c = 1; $c -le $cols; $c++) {
        $val = $sheet.Cells.Item($r, $c).Text
        if ($val) {
            Write-Host ("  " + $headers[$c-1] + ": " + $val.Substring(0, [Math]::Min(100, $val.Length)))
        }
    }
}

$wb.Close($false)
$excel.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
