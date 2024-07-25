
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

$appVendor = 'Cisco'
$appName = 'AnyConnect VPN'

$installedApp = Get-ChildItem -Path HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object { $_.DisplayName -match 'Cisco AnyConnect Secure Mobility Client' } | 
Where-Object { $_.SystemComponent -notmatch '1' } | Select-Object -Property DisplayName, DisplayVersion, UninstallString
            
if ($installedApp.DisplayName -match "Cisco AnyConnect Secure Mobility Client") {
    Write-Output ($appVendor + $appName + $installedApp.DisplayVersion + " installed. Uninstalling now...")
    $x = Start-Process "C:\Program Files (x86)\Cisco\Cisco AnyConnect Secure Mobility Client\Uninstall.exe" -ArgumentList "-remove -silent" -NoNewWindow -PassThru -Wait
    Write-Output ($appVendor + $appName + " Uninstalled. " + $x.HasExited + " - ExitCode: " + $x.ExitCode)

    # Remove Diagnostics and Reporting Tool if left installed
    $installedApp2 = Get-ChildItem -Path HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object { $_.DisplayName -eq 'Cisco AnyConnect Diagnostics and Reporting Tool' } | 
    Select-Object -Property DisplayName, DisplayVersion, UninstallString
    if ($installedApp2.DisplayName -match 'Cisco AnyConnect Diagnostics and Reporting Tool') {
        Write-Output "Removing Cisco AnyConnect Diagnostics and Reporting Tool..."
        $uninstallGUID = $InstalledApp2.UninstallString
        $appID = $uninstallGUID.Substring($uninstallGUID.Length - 38)
        $y = start-process msiexec.exe -ArgumentList "/X $appID /qn /norestart" -Wait -NoNewWindow -PassThru
        Write-Output ($installedApp2.DisplayName + " version " + $installedApp2.DisplayVersion + " uninstalled: " + $y.HasExited + " - ExitCode: " + $y.ExitCode)
    }
    else {}
                
}
else {
    Write-Output ("No installation of " + $appVendor + $appName + " detected. Exiting without removing anything.")
}