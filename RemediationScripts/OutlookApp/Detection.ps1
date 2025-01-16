# Detection Script
$ErrorActionPreference = "Stop"

# Get Windows version information
$windowsVersion = [System.Environment]::OSVersion.Version
$isWindows11 = $windowsVersion.Major -eq 10 -and $windowsVersion.Build -ge 22000
$isWindows10 = $windowsVersion.Major -eq 10 -and $windowsVersion.Build -lt 22000

Write-Output "Detected OS Version: $($windowsVersion.ToString())"
Write-Output "Is Windows 11: $isWindows11"
Write-Output "Is Windows 10: $isWindows10"

if (-not ($isWindows10 -or $isWindows11)) {
    Write-Output "Unsupported Windows version detected."
    Exit 0  # Exit successfully as we don't want to remediate unsupported OS versions
}

# Registry paths
$registryPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe"
$registryName = "BlockedOobeUpdaters"
$desiredValue = '["MS_Outlook"]'
$orchestratorPath = "$registryPath\OutlookUpdate"

try {
    $needsRemediation = $false

    # Check if registry path exists
    if (-not (Test-Path $registryPath)) {
        Write-Output "Registry path does not exist."
        $needsRemediation = $true
    } else {
        # Check if registry value exists and matches desired value
        $currentValue = Get-ItemProperty -Path $registryPath -Name $registryName -ErrorAction SilentlyContinue
        if ($currentValue.$registryName -ne $desiredValue) {
            Write-Output "Registry value is not correctly configured."
            $needsRemediation = $true
        }
    }

    # Additional Windows 11 specific checks
    if ($isWindows11) {
        # Check for Windows 11 23H2 and later specific registry value
        if (Test-Path $orchestratorPath) {
            Write-Output "Windows 11 Orchestrator registry value exists and needs removal."
            $needsRemediation = $true
        }
    }

    if ($needsRemediation) {
        Exit 1
    } else {
        Write-Output "Configuration is correct for the detected Windows version."
        Exit 0
    }
} catch {
    Write-Error "Error occurred during detection: $_"
    Exit 1
}
