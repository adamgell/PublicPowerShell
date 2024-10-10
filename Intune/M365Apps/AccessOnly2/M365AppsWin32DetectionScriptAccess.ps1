# Ensure running in 64-bit
if (-not [Environment]::Is64BitProcess) {
    if ([Environment]::Is64BitOperatingSystem) {
        # Relaunch as 64-bit process
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
        if ($RequireAccess) {
            $arguments += " -RequireAccess"
        }
        Start-Process -FilePath "$env:SystemRoot\sysnative\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $arguments -Wait -NoNewWindow
        exit
    }
    else {
        Write-Warning "This script must be run on a 64-bit system."
        exit 1
    }
}

# Define the required Office applications
#$RequiredOfficeApps = @("WINWORD.EXE", "EXCEL.EXE", "POWERPNT.EXE", "OUTLOOK.EXE", "MSACCESS.EXE")


# Define the required Office applications
$RequiredOfficeApps = @("WINWORD.EXE", "EXCEL.EXE", "MSACCESS.EXE")

function Write-LogEntry {
    param (
        [parameter(Mandatory = $true, HelpMessage = "Value added to the log file.")]
        [ValidateNotNullOrEmpty()]
        [string]$Value,
        
        [parameter(Mandatory = $true, HelpMessage = "Severity for the log entry. 1 for Informational, 2 for Warning and 3 for Error.")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("1", "2", "3")]
        [string]$Severity,
        
        [parameter(Mandatory = $false, HelpMessage = "Name of the log file that the entry will written to.")]
        [ValidateNotNullOrEmpty()]
        [string]$FileName = $LogFileName
    )
    
    # Determine log file location
    $LogDirectory = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
    $LogFilePath = Join-Path -Path $LogDirectory -ChildPath $FileName
    
    # Create the log directory if it doesn't exist
    if (-not (Test-Path -Path $LogDirectory)) {
        try {
            New-Item -Path $LogDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-Verbose "Created log directory: $LogDirectory"
        }
        catch {
            Write-Warning "Failed to create log directory. Error: $($_.Exception.Message)"
            return
        }
    }
	
    # Construct time stamp for log entry
    $Time = -join @((Get-Date -Format "HH:mm:ss.fff"), " ", (Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias))
	
    # Construct date for log entry
    $Date = (Get-Date -Format "MM-dd-yyyy")
	
    # Construct context for log entry
    $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
	
    # Construct final log entry
    $LogText = "<![LOG[$($Value)]LOG]!><time=""$($Time)"" date=""$($Date)"" component=""$($FileName)"" context=""$($Context)"" type=""$($Severity)"" thread=""$($PID)"" file="""">"
	
    # Add value to log file
    try {
        Out-File -InputObject $LogText -Append -NoClobber -Encoding Default -FilePath $LogFilePath -ErrorAction Stop
        switch ($Severity) {
            "1" { Write-Verbose -Message $Value }
            "2" { Write-Warning -Message $Value }
            "3" { Write-Error -Message $Value }
        }
    }
    catch [System.Exception] {
        Write-Warning -Message "Unable to append log entry to $FileName file. Error message at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
    }
}

$LogFileName = "M365AppsDetection.log"
$computername = $env:COMPUTERNAME
Write-LogEntry -Value "Start Office Install detection logic" -Severity 1

# Define possible Office paths
$OfficePaths = @(
    "C:\Program Files\Microsoft Office\root\Office16",
    "C:\Program Files (x86)\Microsoft Office\root\Office16"
)

$DetectedApps = @()
$MissingApps = @()

foreach ($app in $RequiredOfficeApps) {
    $appFound = $false
    foreach ($path in $OfficePaths) {
        $appPath = Join-Path -Path $path -ChildPath $app
        if (Test-Path $appPath) {
            $DetectedApps += $app
            Write-LogEntry -Value "$app detected at $appPath" -Severity 1
            $appFound = $true
            break
        }
    }
    if (-not $appFound) {
        $MissingApps += $app
        Write-LogEntry -Value "$app not found in any of the searched paths" -Severity 2
    }
}

if ($DetectedApps.Count -eq $RequiredOfficeApps.Count) {
    Write-LogEntry -Value "All required Microsoft 365 Apps detected" -Severity 1
    $detectedAppsList = $DetectedApps -join ", "
    Write-LogEntry -Value "Detected Office applications: $detectedAppsList" -Severity 1
    Write-Host "All required Microsoft 365 Apps Detected. Found applications: $detectedAppsList" -foregroundcolor Green
    Write-LogEntry -Value "End Office Install detection logic, Uploading log" -Severity 1
    Exit 0
}
else {
    $missingAppsList = $MissingApps -join ", "
    Write-LogEntry -Value "Missing required Office applications: $missingAppsList" -Severity 2
    Write-Output "Not all required Microsoft 365 Apps Detected. Missing applications: $missingAppsList"
    Exit 1
}