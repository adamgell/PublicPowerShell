# Define the registry paths
# Define the registry paths
$registryPaths = @(
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate',
    'HKLM:\SOFTWARE\POLICIES\Microsoft\Windows\Update\AU',
    'HKLM:\SOFTWARE\POLICIES\Microsoft\Windows\Update',
    # https://conditionalaccess.uk/my-windows-autopatch-experience/
    "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\GPCache\CacheSet001\WindowsUpdate",
    "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\GPCache\CacheSet002\WindowsUpdate"
)

# Loop through each registry path-
foreach ($registryPath in $registryPaths) {
    # Check if the registry path exists
    if (Test-Path $registryPath) {
        Remove-Item -Path $registryPath -Recurse -Force
        Write-Output "All items under '$registryPath' have been removed. Including the key itself."
    }
    else {
        Write-Output "The path '$registryPath' does not exist."
    }
}