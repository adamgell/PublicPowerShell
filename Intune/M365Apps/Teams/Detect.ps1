# Initialize variable to track installation detection using Get-AppPackage
$detectAppPackage = $false

# Retrieve the AppPackage information for Microsoft Teams installed for any user
$teamsAppPackage = Get-AppPackage -AllUsers *MSTeams*

# Check if the installation location of the retrieved package exists
$installLocationExists = Test-Path $teamsAppPackage.InstallLocation -ErrorAction SilentlyContinue

# Determine if Teams is installed based on the AppPackage installation path
if ($installLocationExists) {
    $detectAppPackage = $true
}
else {
    $detectAppPackage = $false
}

# Check if Teams is installed in start menu
$detectAppStartMenu = $false


$teamsStartMenu = Test-Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Teams.lnk" -ErrorAction SilentlyContinue

# Determine if the Start Menu shortcut exists
if ($teamsStartMenu) {
    $detectAppStartMenu = $true
}
else {
    $detectAppStartMenu = $false
}

#check for ICO file in ProgramData  "C:\ProgramData\Microsoft\teams.ico"
$teamsIcon = Test-Path "C:\ProgramData\Microsoft\teams.ico" -ErrorAction SilentlyContinue
if ($teamsIcon) {
    $teamsIcon = $true
}
else {
    $teamsIcon = $false
}

Write-Output $detectAppPackage
Write-Output $detectAppStartMenu
Write-Output $teamsIcon

# Display the overall installation status based on both detection methods
if ($detectAppStartMenu -eq $true -and $detectAppPackage -eq $true -and $teamsIcon -eq $true) {
    Write-Host "Microsoft Teams client is installed."
    Exit 0 
}
else {
    Write-Host "Microsoft Teams client not found."
    Exit 1
}
