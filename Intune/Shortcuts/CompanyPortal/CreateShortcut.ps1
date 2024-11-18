$WScriptShell = New-Object -ComObject WScript.Shell
$ShortcutPath = "$env:PUBLIC\Desktop\Company Portal.lnk"

# Get the package family name for Intune Company Portal
$AppName = "Microsoft.CompanyPortal"
$Package = Get-AppxPackage | Where-Object {$_.Name -eq $AppName}

if ($Package) {
    $PackageFamilyName = $Package.PackageFamilyName
    $ApplicationId = "App"
    
    # Create the protocol URI for the APPX package
    $TargetPath = "shell:AppsFolder\$PackageFamilyName!$ApplicationId"
    
    # Create shortcut
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $TargetPath
    $Shortcut.Save()
    
    Write-Host "Shortcut created successfully at: $ShortcutPath"
} else {
    Write-Host "Error: Intune Company Portal is not installed on this device."
}