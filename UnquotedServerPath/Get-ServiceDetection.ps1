# Detection
$services = Get-CIMInstance -Class Win32_Service | Select-Object Name, PathName, DisplayName, StartMode | Where-Object { $_.StartMode -eq 'Auto' -and $_.PathName -notmatch 'Windows' -and $_.PathName -notmatch '"' }
if ($services) {
    $services.Name 
    $services.PathName
    exit 1
}
else {
    Write-Host ("No Service found without quotes")
    exit 
}