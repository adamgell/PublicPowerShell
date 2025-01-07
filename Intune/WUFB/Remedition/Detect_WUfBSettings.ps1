# Define the registry paths
# PowerShell script to check if specified registry paths exist and remove all keys inside them if they do

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


# Loop through each registry path-
foreach ($registryPath in $registryPaths) {
    # Output the detection result
    if ($entryFound) {
        Write-Output "Registry entries found"
        exit 1  # Indicates remediation is needed
    }
    else {
        Write-Output "Registry entries not found"
        exit 0  # Indicates no remediation needed
    }
}

