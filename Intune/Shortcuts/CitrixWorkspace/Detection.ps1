# Detection script for Citrix Workspace shortcut
$ErrorActionPreference = "SilentlyContinue"

# Check for shortcut
$shortcutPath = "C:\Users\Public\Desktop\CitrixWorkspace.lnk"
$shortcutExists = Test-Path $shortcutPath

# Final detection logic
if ($shortcutExists) {
    Write-Host "Citrix Workspace shortcut exists"
    exit 0  # Success
} else {
    Write-Host "Citrix Workspace shortcut not found"
    exit 1  # Failure
}