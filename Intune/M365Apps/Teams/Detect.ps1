# Initialize variable to track installation detection using file system approach
$detectWinApps = $false

# Define the path where Microsoft Teams is typically installed via Windows Apps
$teamsPath = "C:\Program Files\WindowsApps"

# Define the naming pattern used by Microsoft Teams installers within the Windows Apps folder
$teamsInstallerName = "MSTeams_*"

# Retrieve files that match the installer naming pattern in the specified directory
$teamsNew = Get-ChildItem -Path $teamsPath -Filter $teamsInstallerName

# Determine if Teams is installed based on retrieved files
if ($null -ne $teamsNew) {
    $detectWinApps = $true
}
else {
    $detectWinApps = $false
}

# Initialize variable to track installation detection using Get-AppPackage
$detectAppPackage = $false

# Retrieve the AppPackage information for Microsoft Teams installed for any user
$teamsAppPackage = Get-AppPackage -AllUsers *MSTeams*

# Check if the installation location of the retrieved package exists
$teamsAppPackage = Test-Path $teamsAppPackage.InstallLocation -ErrorAction SilentlyContinue

# Determine if Teams is installed based on the AppPackage installation path
if ($null -ne $teamsAppPackage) {
    $detectAppPackage = $true
}
else {
    $detectAppPackage = $false
}

# check if Teams is installed in start menu
$detectAppStartMenu = $false
$teamsStartMenu = Test-path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Teams.lnk" -ErrorAction SilentlyContinue
if ($null -ne $teamsStartMenu) {
    $detectAppStartMenu = $true
}
else {
    $detectAppStartMenu = $false
}



# Output the status of Teams installation detection via both methods
Write-Output $detectWinApps
Write-Output $detectAppPackage
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