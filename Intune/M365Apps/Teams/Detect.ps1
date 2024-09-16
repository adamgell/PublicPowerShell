# check if Teams is installed in start menu
$detectAppStartMenu = $false
$teamsStartMenu = Test-path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Teams.lnk" -ErrorAction SilentlyContinue
if ($null -ne $teamsStartMenu) {
    $detectAppStartMenu = $true
}
else {
    $detectAppStartMenu = $false
}

Write-Output $detectAppStartMenu

# Display the overall installation status based on both detection methods
if ($detectAppStartMenu -eq $true) {
    Write-Host "Microsoft Teams client is installed."
    Exit 0 
}
else {
    Write-Host "Microsoft Teams client not found."
    Exit 1
} 