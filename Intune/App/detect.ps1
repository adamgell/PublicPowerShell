# Define the MSI product names or product codes to detect
$msiProductNames = @(
    "",
    "",
    "",
)

# Function to check if a product is installed
function Is-MsiInstalled {
    param (
        [string]$ProductName
    )

    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($path in $registryPaths) {
        $installed = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -eq $ProductName }

        if ($installed) {
            return $true
        }
    }

    return $false
}

# Main detection logic
$allInstalled = $true

foreach ($product in $msiProductNames) {
    if (-not (Is-MsiInstalled -ProductName $product)) {
        $allInstalled = $false
        break
    }
}

# Output result for Win32 app detection
if ($allInstalled) {
    Write-Host "All MSIs are installed."
    exit 0  # Detection successful
} else {
    Write-Host "One or more MSIs are not installed."
    exit 1  # Detection failed
}
