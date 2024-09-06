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

$serials = "0042-6229-1966-4379-7349-1047-98", "Serial2", "Serial3"

# Get current device information and apply Group Tag
foreach ($serial in $serials) {
    Write-Host "Deleting device $serial"
    $device = Get-AutopilotDevice -serial $serial
    if ($device) {
        Remove-AutopilotDevice -id $device.id
    } else {
        Write-Host "Device not found"
    }
    
}
