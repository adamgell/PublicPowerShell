# Check if the module WindowsAutopilotIntune is installed, if not, install it
if (-not (Get-Module -ListAvailable -Name WindowsAutopilotIntune)) {
    Install-Module -Name WindowsAutopilotIntune -Force -AllowClobber
}

if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Install-Module -Name Microsoft.Graph.Authentication -Force -AllowClobber
}
Import-Module WindowsAutopilotIntune
Import-Module Microsoft.Graph.Authentication

# Connect to Microsoft Graph with the required scopes
$scopes = @("DeviceManagementServiceConfig.ReadWrite.All", "Directory.ReadWrite.All")
Connect-MgGraph -Scopes $scopes

$temp = "C:\Temp"
if (-not (Test-Path $temp)) {
    New-Item -Path $temp -ItemType Directory
}

# Retrieve the autopilot devices
$autopilotDevices = Get-AutopilotDevice

# Display the id property of each autopilot device and ensure uniqueness
foreach ($device in $autopilotDevices) {
    $device.id | Out-File C:\temp\AutopilotDeviceIDlist.txt -Append
}

# Provide a Group Tag
$Grouptag = "ChangeMe2"

# Get the unique IDs
$DeviceIDs = Get-Content "C:\temp\AutopilotDeviceIDlist.txt" | Sort-Object -Unique

# Get current device information and apply Group Tag
foreach ($deviceID in $DeviceIDs) {
    $currentDevice = Get-AutopilotDevice -id $deviceID
    Write-Host "Working on device $deviceID"
    
    # Apply Group Tag if it's not already set
    if ($currentDevice.groupTag -ne $Grouptag) {
        Set-AutopilotDevice -id $deviceID -groupTag $Grouptag
    } else {
        Write-Host "Group Tag already set"
    }
}
