# Define the registry paths
$registryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update',
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate',
    'HKLM:\SOFTWARE\POLICIES\Microsoft\Windows\Update\AU',
    'HKLM:\SOFTWARE\POLICIES\Microsoft\Windows\Update',
    # https://conditionalaccess.uk/my-windows-autopatch-experience/
    "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\GPCache\CacheSet001\WindowsUpdate",
    "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\GPCache\CacheSet002\WindowsUpdate"
)


# Define the registry entries to check
$registryEntries = @("ManagePreviewBuilds", "ManagePreviewBuilds_ProviderSet", "ManagePreviewBuilds_WinningProvider")

# Flag to track if any registry entry is found
$entryFound = $false

# Loop through each registry path
foreach ($registryPath in $registryPaths) {
    # Check if the registry path exists
    if (Test-Path $registryPath) {
        # Loop through each registry entry
        foreach ($entry in $registryEntries) {
            # Check if the registry value exists
            $value = Get-ItemProperty -Path $registryPath -Name $entry -ErrorAction SilentlyContinue
            if ($null -ne $value) {
                # Set flag to true if any entry is found
                $entryFound = $true
                break
            }
        }
    }
}

# Output the detection result
if ($entryFound) {
    Write-Output "Registry entries found"
    exit 1  # Indicates remediation is needed
} else {
    Write-Output "Registry entries not found"
    exit 0  # Indicates no remediation needed
}
