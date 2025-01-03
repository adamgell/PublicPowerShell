# IntuneDriverManagement.psm1

using module .\classes\IntuneDevice.ps1

# Define script-level variables
$script:ModuleRoot = $PSScriptRoot

# Get public and private function definitions
$Public = @(Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue)

# Dot source the functions
foreach ($import in @($Public + $Private)) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}

# Export public functions and the IntuneDevice class
Export-ModuleMember -Function $Public.BaseName -Variable *