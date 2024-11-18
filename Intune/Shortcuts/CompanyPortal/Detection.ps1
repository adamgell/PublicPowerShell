$ShortcutPath = "$env:PUBLIC\Desktop\Company Portal.lnk"
$AppName = "Microsoft.CompanyPortal"
$exitCode = 1

# Check if Company Portal is installed
$Package = Get-AppxPackage | Where-Object {$_.Name -eq $AppName}

# Check if shortcut exists
$ShortcutExists = Test-Path $ShortcutPath

if ($Package -and $ShortcutExists) {
    $exitCode = 0
    Write-Host "Company Portal is installed and shortcut exists."
} else {
    Write-Host "Detection failed:"
    if (-not $Package) { Write-Host "- Company Portal is not installed" }
    if (-not $ShortcutExists) { Write-Host "- Shortcut does not exist" }
}

exit $exitCode