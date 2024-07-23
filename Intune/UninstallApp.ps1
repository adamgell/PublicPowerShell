<#
.SYNOPSIS
    This script removes specified MSI applications and searches the registry for "CISCO AMP" to uninstall it.
.DESCRIPTION
    This script uninstalls applications using their MSI product codes and then searches the registry for an application named "CISCO AMP" to find and execute its uninstall string.
.PARAMETER None
    This script does not require any parameters.
.EXAMPLE
    .\Remove-Software.ps1
#>

[CmdletBinding()]
param ()

# Uninstall specified MSI applications
$msiProductCodes = @(
    "{3D4EC318-214E-4E84-B226-6709714CBB65}",
    "{92C00108-BE42-4D8C-89A3-3A97FF8DCA82}"
)

foreach ($productCode in $msiProductCodes) {
    try {
        Write-Verbose "Uninstalling MSI application with product code: $productCode"
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/X$productCode /qn" -Wait -NoNewWindow
        Write-Output "Successfully uninstalled application with product code: $productCode"
    } catch {
        Write-Error "Failed to uninstall application with product code: $productCode. Error: $_"
    }
}

# Search the registry for "CISCO AMP" and uninstall it
try {
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    $ampKey = Get-ChildItem -Path $registryPath | Get-ItemProperty | Where-Object { $_.DisplayName -like "*Cisco Amp*" }

    if ($ampKey) {
        Write-Verbose "Found CISCO AMP in the registry."
        $uninstallString = $ampKey.UninstallString

        if ($uninstallString) {
            $productCode = [regex]::Match($uninstallString, '{[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}}').Value
            Write-Verbose "Uninstalling CISCO AMP using product code: $productCode"
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/X$productCode /qn" -Wait -NoNewWindow
            Write-Output "Successfully uninstalled CISCO AMP"
        } else {
            Write-Warning "No valid uninstall string found for CISCO AMP."
        }
    } else {
        Write-Warning "CISCO AMP not found in the registry."
    }
} catch {
    Write-Error "Failed to uninstall CISCO AMP. Error: $_"
}
