# Check PowerShellGet version first
$powerShellGetVersion = (Get-Module -ListAvailable -Name PowerShellGet | Sort-Object Version -Descending | Select-Object -First 1).Version
Write-Host "Current PowerShellGet Version: $powerShellGetVersion"

if ($powerShellGetVersion -lt [Version]"2.2.5") {
    Write-Host "PowerShellGet needs to be updated to version 2.2.5 or higher"
    $confirmation = Read-Host "Do you want to update PowerShellGet now? (Y/N)"
    if ($confirmation -eq 'Y') {
        Write-Host "Installing latest version of PowerShellGet..."
        Write-Host "Please close this terminal after the script completes and reopen to use the updated module."
        Install-Module -Name PowerShellGet -Force -AllowClobber -MinimumVersion 2.2.5
        exit
    } else {
        Write-Host "Script cannot continue without PowerShellGet 2.2.5 or higher"
        exit
    }
}

# Check if the module WindowsAutopilotIntune is installed, if not, install it
if (-not (Get-Module -ListAvailable -Name WindowsAutopilotIntune)) {
    Install-Module -Name WindowsAutopilotIntune -Force -AllowClobber
}

if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Install-Module -Name Microsoft.Graph.Authentication -Force -AllowClobber
}
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Entra)) {
    Install-Module -Name Microsoft.Graph.Entra -Force -AllowClobber
}

Import-Module WindowsAutopilotIntune -Force 
Import-Module Microsoft.Graph.Authentication -Force
Import-Module Microsoft.Graph.Entra -Force

# Get script's directory and construct full paths
$currentDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$csvFile = Join-Path $currentDir "serials.csv"
$outputFile = Join-Path $currentDir "ObjectIDList.csv"
$logFile = Join-Path $currentDir "script_log.txt"

# Start Transcript for logging
Start-Transcript -Path $logFile -Force

Write-Host "Script Directory: $currentDir"
Write-Host "Input CSV Path: $csvFile"
Write-Host "Output CSV Path: $outputFile"
Write-Host "Log File Path: $logFile"

# Check if ObjectIDList.csv exists and ask to delete
if (Test-Path $outputFile) {
    $confirmation = Read-Host "ObjectIDList.csv already exists in the script directory. Do you want to delete it? (Y/N)"
    if ($confirmation -eq 'Y') {
        Remove-Item $outputFile
        Write-Host "Existing ObjectIDList.csv deleted."
    } else {
        Write-Host "Operation cancelled. Please remove or rename the existing ObjectIDList.csv and try again."
        Stop-Transcript
        exit
    }
}

# Verify input CSV file exists and has content
if (-not (Test-Path $csvFile)) {
    Write-Error "serials.csv not found in script directory!"
    Stop-Transcript
    exit
}

$csvContent = Import-Csv $csvFile
if ($null -eq $csvContent -or @($csvContent).Count -eq 0) {
    Write-Error "serials.csv is empty or not properly formatted!"
    Stop-Transcript
    exit
}

# Create the initial CSV with version header
"version:v1.0" | Set-Content -Path $outputFile
"[memberObjectIdOrUpn]" | Add-Content -Path $outputFile

# Connect to Microsoft Graph with the required scopes
$scopes = @("DeviceManagementServiceConfig.Read.All", "Device.Read.All")
Connect-MgGraph -Scopes $scopes -NoWelcome

# Initialize counters
$totalDevices = @($csvContent).Count
$processedDevices = 0
$successfulDevices = 0
$failedDevices = 0

# Get csv file with the list of devices to search for 
$devices = Import-Csv $csvFile

foreach ($device in $devices) {
    $processedDevices++
    # Assuming the CSV has a column named 'SerialNumber'
    $serialNumber = $device.SerialNumber
    Write-Host "`nProcessing device $processedDevices of $totalDevices"
    Write-Host "Searching for device with Serial Number: $serialNumber"
    
    try {
        # Get Autopilot device by serial number
        $autopilotDevice = Get-AutopilotDevice | Where-Object { $_.serialNumber -eq $serialNumber }
        
        if ($null -eq $autopilotDevice) {
            Write-Host "No Autopilot device found with Serial Number: $serialNumber" -ForegroundColor Yellow
            $failedDevices++
            continue
        }

        $AP_DeviceID = $autopilotDevice.azureAdDeviceId
        Write-Host "Autopilot Device ID: $AP_DeviceID"
        
        if ($null -eq $AP_DeviceID) {
            Write-Host "No Azure AD Device ID found for Serial Number: $serialNumber" -ForegroundColor Yellow
            $failedDevices++
            continue
        }

        # Get object id of $AP_DeviceID
        $objectid = Get-EntraDevice -Filter "DeviceId eq '$AP_DeviceID'" | Select-Object -ExpandProperty Id
        
        if ($objectid) {
            Write-Host "Found Entra Device Object ID: $objectid" -ForegroundColor Green
            # Add just the ObjectID to the CSV file
            $objectid | Add-Content -Path $outputFile
            $successfulDevices++
        } else {
            Write-Host "No Entra device found with Device ID: $AP_DeviceID" -ForegroundColor Yellow
            $failedDevices++
        }
    }
    catch {
        Write-Error "Error processing Serial Number $serialNumber : $_"
        $failedDevices++
    }
}

# Display summary
Write-Host "`n=== Processing Summary ===" -ForegroundColor Cyan
Write-Host "Total devices processed: $totalDevices"
Write-Host "Successfully processed: $successfulDevices" -ForegroundColor Green
Write-Host "Failed to process: $failedDevices" -ForegroundColor Yellow
Write-Host "Success rate: $([math]::Round(($successfulDevices/$totalDevices)*100,2))%"

Write-Host "`nScript completed. Please check:"
Write-Host "- Output file: $outputFile"
Write-Host "- Log file: $logFile"

Stop-Transcript