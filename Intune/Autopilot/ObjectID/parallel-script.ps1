#Requires -Version 7.0
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

# Register and trust PSGallery
if (-not (Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue)) {
    Register-PSRepository -Default
}
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted

# Install modules with proper flags
$modules = @(
    @{
        Name = 'WindowsAutopilotIntune'
        AllowPrerelease = $false
    },
    @{
        Name = 'Microsoft.Graph.Authentication'
        AllowPrerelease = $false
    }
)

foreach ($module in $modules) {
    Write-Host "Checking module: $($module.Name)"
    if (-not (Get-Module -ListAvailable -Name $module.Name)) {
        try {
            Install-Module @module -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
            Write-Host "$($module.Name) installed successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "Error installing $($module.Name): $_" -ForegroundColor Red
            exit
        }
    }
    Import-Module $module.Name -Force
}

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
    }
    else {
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

$devices = Import-Csv $csvFile
if ($null -eq $devices -or @($devices).Count -eq 0) {
    Write-Error "serials.csv is empty or not properly formatted!"
    Stop-Transcript
    exit
}

# Create the initial CSV with version header
"version:v1.0" | Set-Content -Path $outputFile
"[memberObjectIdOrUpn]" | Add-Content -Path $outputFile

# Connect to Microsoft Graph and save connection info
$graphConnection = Connect-MgGraph -Scopes @("DeviceManagementServiceConfig.Read.All", "Device.Read.All") -NoWelcome
$mgContext = Get-MgContext

if (-not $mgContext) {
    Write-Error "Failed to establish Microsoft Graph connection"
    Stop-Transcript
    exit
}

# Initialize counters
$totalDevices = $devices.Count
$processedDevices = 0
$successfulDevices = 0
$failedDevices = 0

# Create a queue of work items
$workQueue = [System.Collections.Queue]::new($devices)
$maxConcurrent = 5
$runningJobs = @{}

# Process queue until empty
while ($workQueue.Count -gt 0 -or $runningJobs.Count -gt 0) {
    # Start new jobs if queue has items and we're below max concurrent
    while ($workQueue.Count -gt 0 -and $runningJobs.Count -lt $maxConcurrent) {
        $device = $workQueue.Dequeue()
        $processedDevices++
        
        $jobScript = {
            param($serialNumber)
            
            try {
                # Get Autopilot device
                Import-Module WindowsAutopilotIntune
                Import-Module Microsoft.Graph.Authentication
                
                # Connect to Graph with same scopes as parent
                Connect-MgGraph -Scopes @("DeviceManagementServiceConfig.Read.All", "Device.Read.All") -NoWelcome | Out-Null
                
                $autopilotDevice = Get-AutopilotDevice | Where-Object { $_.serialNumber -eq $serialNumber }
                if ($null -eq $autopilotDevice) {
                    return @{
                        Success = $false
                        Message = "No Autopilot device found"
                        SerialNumber = $serialNumber
                    }
                }

                $AP_DeviceID = $autopilotDevice.azureAdDeviceId
                if ($null -eq $AP_DeviceID) {
                    return @{
                        Success = $false
                        Message = "No Azure AD Device ID found"
                        SerialNumber = $serialNumber
                    }
                }

                # Query Graph API
                $graphUri = "https://graph.microsoft.com/v1.0/devices?`$filter=deviceId eq '$AP_DeviceID'"
                $graphResponse = Invoke-MgGraphRequest -Uri $graphUri -Method GET
                $objectId = $graphResponse.value[0].id
                
                if ($objectId) {
                    return @{
                        Success = $true
                        ObjectId = $objectId
                        SerialNumber = $serialNumber
                    }
                }
                else {
                    return @{
                        Success = $false
                        Message = "No device found in Graph API"
                        SerialNumber = $serialNumber
                    }
                }
            }
            catch {
                return @{
                    Success = $false
                    Message = $_.Exception.Message
                    SerialNumber = $serialNumber
                }
            }
        }

        $job = Start-Job -ScriptBlock $jobScript -ArgumentList $device.SerialNumber
        $runningJobs[$job.Id] = @{
            Job = $job
            SerialNumber = $device.SerialNumber
            StartTime = Get-Date
        }
    }

    # Check completed jobs
    $completedJobs = @($runningJobs.Keys | Where-Object { $runningJobs[$_].Job.State -eq 'Completed' })
    foreach ($jobId in $completedJobs) {
        $jobInfo = $runningJobs[$jobId]
        $result = Receive-Job -Job $jobInfo.Job

        # Write result with color coding
        if ($result.Success) {
            Write-Host "Success: Serial $($result.SerialNumber) - ObjectId: $($result.ObjectId)" -ForegroundColor Green
            $result.ObjectId | Add-Content -Path $outputFile
            $successfulDevices++
        }
        else {
            Write-Host "Failed: Serial $($result.SerialNumber) - $($result.Message)" -ForegroundColor Yellow
            $failedDevices++
        }

        # Cleanup job
        Remove-Job -Job $jobInfo.Job
        $runningJobs.Remove($jobId)
    }

    # Progress update
    Write-Progress -Activity "Processing Devices" -Status "Processing $($runningJobs.Count) devices" `
        -PercentComplete (($processedDevices / $totalDevices) * 100) `
        -CurrentOperation "Completed: $($successfulDevices + $failedDevices) of $totalDevices"

    Start-Sleep -Milliseconds 100
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