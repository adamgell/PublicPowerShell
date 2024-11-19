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

# Initialize counters using thread-safe variables
$totalDevices = @($csvContent).Count
$script:processedDevices = [int]0
$script:successfulDevices = [int]0
$script:failedDevices = [int]0

# Create a mutex for thread-safe file writing
$mutex = [System.Threading.Mutex]::new($false, "OutputFileMutex")

# Get csv file with the list of devices to search for 
$devices = Import-Csv $csvFile

# Set the maximum number of parallel jobs
$maxParallelJobs = 10

# Create a throttle limit parameter
$throttleLimit = [int]::Min($maxParallelJobs, $totalDevices)

# Process devices in parallel
$devices | ForEach-Object -ThrottleLimit $throttleLimit -Parallel {
    # Import required modules in parallel runspace
    Import-Module Microsoft.Graph.Authentication -ErrorAction SilentlyContinue
    Import-Module WindowsAutopilotIntune -ErrorAction SilentlyContinue

    # Get variables from parent scope
    $outputFile = $using:outputFile
    $mutex = $using:mutex

    # Assuming the CSV has a column named 'SerialNumber'
    $serialNumber = $_.SerialNumber
    $processedCount = [System.Threading.Interlocked]::Increment([ref]$using:processedDevices)
    
    Write-Host "`nProcessing device $processedCount of $using:totalDevices"
    Write-Host "Searching for device with Serial Number: $serialNumber"
    
    try {
        # Get Autopilot device by serial number
        $autopilotDevice = Get-AutopilotDevice | Where-Object { $_.serialNumber -eq $serialNumber }
        
        if ($null -eq $autopilotDevice) {
            Write-Host "No Autopilot device found with Serial Number: $serialNumber" -ForegroundColor Yellow
            [System.Threading.Interlocked]::Increment([ref]$using:failedDevices)
            return
        }

        $AP_DeviceID = $autopilotDevice.azureAdDeviceId
        Write-Host "Autopilot Device ID: $AP_DeviceID"
        
        if ($null -eq $AP_DeviceID) {
            Write-Host "No Azure AD Device ID found for Serial Number: $serialNumber" -ForegroundColor Yellow
            [System.Threading.Interlocked]::Increment([ref]$using:failedDevices)
            return
        }

        # Use direct Graph API request
        $graphUri = "https://graph.microsoft.com/v1.0/devices?`$filter=deviceId eq '$AP_DeviceID'"
        try {
            $graphResponse = Invoke-MgGraphRequest -Uri $graphUri -Method GET
            $objectId = $graphResponse.value[0].id
            
            if ($objectId) {
                Write-Host "Found Device Object ID: $objectId" -ForegroundColor Green
                
                # Thread-safe file writing using mutex
                $mutex.WaitOne() | Out-Null
                try {
                    $objectId | Add-Content -Path $outputFile
                } finally {
                    $mutex.ReleaseMutex()
                }
                
                [System.Threading.Interlocked]::Increment([ref]$using:successfulDevices)
            } else {
                Write-Host "No device found with Device ID: $AP_DeviceID" -ForegroundColor Yellow
                [System.Threading.Interlocked]::Increment([ref]$using:failedDevices)
            }
        } catch {
            Write-Host "Error querying Graph API: $_" -ForegroundColor Red
            [System.Threading.Interlocked]::Increment([ref]$using:failedDevices)
        }
    }
    catch {
        Write-Error "Error processing Serial Number $serialNumber : $_"
        [System.Threading.Interlocked]::Increment([ref]$using:failedDevices)
    }
} -AsJob | Wait-Job | Receive-Job

# Display summary
Write-Host "`n=== Processing Summary ===" -ForegroundColor Cyan
Write-Host "Total devices processed: $totalDevices"
Write-Host "Successfully processed: $script:successfulDevices" -ForegroundColor Green
Write-Host "Failed to process: $script:failedDevices" -ForegroundColor Yellow
Write-Host "Success rate: $([math]::Round(($script:successfulDevices/$totalDevices)*100,2))%"

Write-Host "`nScript completed. Please check:"
Write-Host "- Output file: $outputFile"
Write-Host "- Log file: $logFile"

# Clean up mutex
$mutex.Dispose()

Stop-Transcript