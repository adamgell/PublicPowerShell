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

# Define the registry entries to remove
$registryEntries = @("ManagePreviewBuilds", "ManagePreviewBuilds_ProviderSet", "ManagePreviewBuilds_WinningProvider")

# Loop through each registry path
foreach ($registryPath in $registryPaths) {
    # Check if the registry path exists
    if (Test-Path $registryPath) {
        try {
            # Loop through each registry entry
            foreach ($entry in $registryEntries) {
                # Check if the registry value exists
                $value = Get-ItemProperty -Path $registryPath -Name $entry -ErrorAction SilentlyContinue
                if ($null -ne $value) {
                    # Remove the registry value
                    Remove-ItemProperty -Path $registryPath -Name $entry -Force
                    Write-Output "The registry value '$entry' has been removed from '$registryPath'."
                }
                else {
                    Write-Output "The registry value '$entry' does not exist in '$registryPath'."
                }
            }
        }
        catch {
            Write-Output "An error occurred while attempting to remove values from '$registryPath'. Error: $_"
        }
    }
    else {
        Write-Output "The path '$registryPath' does not exist."
    }
}
