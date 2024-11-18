# Define shortcut path and target parameters
$shortcutPath = "C:\Users\Public\Desktop\CitrixWorkspace.lnk"
$targetPath = "C:\Program Files (x86)\Citrix\ICA Client\SelfServicePlugin\SelfService.exe"

# Create Shell COM object
$WScriptShell = New-Object -ComObject WScript.Shell

# Function to create shortcut
function Create-Shortcut {
    try {
        $Shortcut = $WScriptShell.CreateShortcut($shortcutPath)
        $Shortcut.TargetPath = $targetPath
        $Shortcut.Arguments = "-showAppPicker"
        $Shortcut.WorkingDirectory = "C:\Program Files (x86)\Citrix\ICA Client\SelfServicePlugin\"
        $Shortcut.Description = "Select applications you want to use on your computer"
        $Shortcut.IconLocation = "C:\Windows\Installer\{03BDC398-A50D-412F-A068-68999D22BCF8}\CRShort,0"
        $Shortcut.WindowStyle = 1
        $Shortcut.Save()
        Write-Host "Shortcut created successfully at $shortcutPath"
    }
    catch {
        Write-Error "Failed to create shortcut: $_"
    }
}

Create-Shortcut