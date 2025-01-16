# Remediation Script
$ErrorActionPreference = "Stop"

# Get Windows version information
$windowsVersion = [System.Environment]::OSVersion.Version
$isWindows11 = $windowsVersion.Major -eq 10 -and $windowsVersion.Build -ge 22000
$isWindows10 = $windowsVersion.Major -eq 10 -and $windowsVersion.Build -lt 22000

Write-Output "Detected OS Version: $($windowsVersion.ToString())"
Write-Output "Is Windows 11: $isWindows11"
Write-Output "Is Windows 10: $isWindows10"

if (-not ($isWindows10 -or $isWindows11)) {
    Write-Output "Unsupported Windows version detected. Exiting."
    Exit 0
}

# Registry paths
$registryPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe"
$registryName = "BlockedOobeUpdaters"
$desiredValue = '["MS_Outlook"]'
$orchestratorPath = "$registryPath\OutlookUpdate"

try {
    # Create registry path if it doesn't exist
    if (-not (Test-Path $registryPath)) {
        New-Item -Path $registryPath -Force | Out-Null
        Write-Output "Created registry path."
    }

    # Set registry value
    Set-ItemProperty -Path $registryPath -Name $registryName -Value $desiredValue -Type String -Force
    Write-Output "Registry value set successfully."

    # Remove Outlook if already installed
    $outlookPackage = Get-AppxPackage Microsoft.OutlookForWindows -ErrorAction SilentlyContinue
    if ($outlookPackage) {
        $packageName = $outlookPackage.PackageFullName
        if ($packageName) {
            Remove-AppxProvisionedPackage -AllUsers -Online -PackageName $packageName -ErrorAction SilentlyContinue
            Write-Output "Removed existing Outlook package."
        }
    }

    # Windows 11 specific remediation
    if ($isWindows11) {
        # Remove Windows 11 Orchestrator registry value if it exists
        if (Test-Path $orchestratorPath) {
            Remove-Item -Path $orchestratorPath -Force
            Write-Output "Removed Windows 11 Orchestrator registry value."
        }
    }

    $osType = if ($isWindows11) { "Windows 11" } else { "Windows 10" }
    Write-Output "Remediation completed successfully for $osType"
    Exit 0
} catch {
    Write-Error "Error occurred during remediation: $_"
    Exit 1
}