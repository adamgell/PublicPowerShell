# Variables
$customerName = "Demo"  # To be set when running

$storageAccount = ""
$containerName = ""
$sasToken = ""

# Build the base URI
$baseUri = "https://$storageAccount.blob.core.windows.net/$containerName"

# Get computer name
$computerName = $env:COMPUTERNAME

$registryPaths = @{
    HKLM = @(
        "SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate",
        "SOFTWARE\Microsoft\WindowsUpdate",
        "SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate"
    )
    HKCU = @(
        "SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\WindowsUpdate",
        "SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    )
}

$report = @{
    CustomerName = $customerName
    ComputerName = $computerName
    TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Policies = @()
}

foreach ($hive in $registryPaths.Keys) {
    foreach ($path in $registryPaths[$hive]) {
        $fullPath = "${hive}:\${path}"
        if (Test-Path $fullPath) {
            $properties = Get-ItemProperty -Path $fullPath -ErrorAction SilentlyContinue
            if ($properties) {
                $policies = $properties | Get-Member -MemberType NoteProperty | 
                    Where-Object { $_.Name -notlike "PS*" }
                
                foreach ($policy in $policies) {
                    $report.Policies += [PSCustomObject]@{
                        Hive = $hive
                        Path = $path
                        Name = $policy.Name
                        Value = $properties.($policy.Name)
                    }
                }
            }
        }
    }
}

# Generate HTML Report
$htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Windows Update Policy Report - $($report.CustomerName) - $($report.ComputerName)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        tr:nth-child(even) { background-color: #f9f9f9; }
    </style>
</head>
<body>
    <h1>Windows Update Policy Report</h1>
    <p>Customer Name: $($report.CustomerName)</p>
    <p>Computer Name: $($report.ComputerName)</p>
    <p>Generated: $($report.TimeStamp)</p>
    <table>
        <tr>
            <th>Registry Hive</th>
            <th>Path</th>
            <th>Policy Name</th>
            <th>Value</th>
        </tr>
"@

foreach ($policy in $report.Policies) {
    $htmlReport += @"
        <tr>
            <td>$($policy.Hive)</td>
            <td>$($policy.Path)</td>
            <td>$($policy.Name)</td>
            <td>$($policy.Value)</td>
        </tr>
"@
}

$htmlReport += @"
    </table>
</body>
</html>
"@

# After HTML generation, before upload
$fileName = "$($report.CustomerName)_$($report.ComputerName)_WUPolicy_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
$reportPath = Join-Path $env:TEMP $fileName
$htmlReport | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "File saved locally at: $reportPath"
Write-Host "File exists: $(Test-Path $reportPath)"
Write-Host "File size: $((Get-Item $reportPath).Length) bytes"

$folderName = "registry-reports"
$uploadUri = "$baseUri/$customerName/$folderName/$fileName$sasToken"
Write-Host "Upload URI: $uploadUri"

$headers = @{
    'x-ms-blob-type' = 'BlockBlob'
    'Content-Type' = 'text/html'
}

try {
    $response = Invoke-RestMethod -Uri $uploadUri -Method Put -Headers $headers -InFile $reportPath -Verbose
    Write-Host "Upload successful"
    Write-Host "Response: $response"
}
catch {
    Write-Host "Upload failed"
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)"
    Write-Host "Status Description: $($_.Exception.Response.StatusDescription)"
}

# Cleanup
Remove-Item $reportPath