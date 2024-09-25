#region LOG FUNCTION
function Log() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)] [String] $message
    )

    $ts = get-date -f "yyyy/MM/dd hh:mm:ss tt"
    Write-Output "$ts $message"
}
#endregion
#region 32-bit to 64-bit process check
# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64") {
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe") {
        Log "Relaunching as 64-bit process"
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath"
        Exit $lastexitcode
    }
}
#endregion
#region Create output folder
# Create output folder
$autopilotBrandingPath = "$($env:ProgramData)\Microsoft\AutopilotBranding"
if (-not (Test-Path $autopilotBrandingPath)) {
    Log "Creating AutopilotBranding directory"
    Mkdir $autopilotBrandingPath -Force
}
#endregion
#region Start logging
# Start logging
Log "Starting transcript"
Start-Transcript "$autopilotBrandingPath\AutopilotBranding.log"
#endregion
#region Creating tag file
# Creating tag file
Log "Creating tag file"
Set-Content -Path "$autopilotBrandingPath\AutopilotBranding.ps1.tag" -Value "Installed"
#endregion
#region Load the Config.xml
# PREP: Load the Config.xml
$installFolder = "$PSScriptRoot\"
Log "Install folder: $installFolder"
Log "Loading configuration: $($installFolder)Config.xml"
[Xml]$config = Get-Content "$($installFolder)Config.xml"
#endregion
#region STEP 1 Apply custom start menu layout
# STEP 1: Apply custom start menu layout
$ci = Get-ComputerInfo
Log "OS Build Number: $($ci.OsBuildNumber)"
if ($ci.OsBuildNumber -le 22000) {
    Log "Importing layout: $($installFolder)Layout.xml"
    Copy-Item "$($installFolder)Layout.xml" "C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.xml" -Force
}
else {
    Log "Importing layout: $($installFolder)Start2.bin"
    $startMenuPath = "C:\Users\Default\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
    MkDir -Path $startMenuPath -Force -ErrorAction SilentlyContinue | Out-Null
    Copy-Item "$($installFolder)Start2.bin" "$startMenuPath\Start2.bin" -Force
}
#endregion
#region STEP 2 Configure background
# STEP 2: Configure background
Log "Loading default user hive"
reg.exe load HKLM\TempUser "C:\Users\Default\NTUSER.DAT" | Out-Host

Log "Setting up Autopilot theme"
Mkdir "C:\Windows\Resources\OEM Themes" -Force | Out-Null
Copy-Item "$installFolder\Autopilot.theme" "C:\Windows\Resources\OEM Themes\Autopilot.theme" -Force
Mkdir "C:\Windows\web\wallpaper\Autopilot" -Force | Out-Null
Copy-Item "$installFolder\Autopilot.jpg" "C:\Windows\web\wallpaper\Autopilot\Autopilot.jpg" -Force
Log "Setting Autopilot theme as the new user default"
reg.exe add "HKLM\TempUser\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes" /v InstallTheme /t REG_EXPAND_SZ /d "%SystemRoot%\resources\OEM Themes\Autopilot.theme" /f | Out-Host
#endregion
#region STEP 2A Stop Start menu from opening on first logon
# STEP 2A: Stop Start menu from opening on first logon
Log "Configuring Start menu to not open on first logon"
reg.exe add "HKLM\TempUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v StartShownOnUpgrade /t REG_DWORD /d 1 /f | Out-Host
#endregion
#region STEP 2B Hide "Learn more about this picture" from the desktop
# STEP 2B: Hide "Learn more about this picture" from the desktop
Log "Hiding 'Learn more about this picture' from desktop"
reg.exe add "HKLM\TempUser\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" /v "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}" /t REG_DWORD /d 1 /f | Out-Host
Log "Unloading default user hive"
reg.exe unload HKLM\TempUser | Out-Host
#endregion
#region STEP 3 Set time zone Set Autopilot.jpg as lock screen image
# STEP 3: Set Autopilot.jpg as lock screen image
Log "Setting Autopilot.jpg as lock screen image"
$LockScreenPath = "C:\Windows\web\wallpaper\Autopilot\Autopilot.jpg"
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"

if (Test-Path $LockScreenPath) {
    try {
        # Create the PersonalizationCSP registry key if it doesn't exist
        if (-not (Test-Path $RegPath)) {
            New-Item -Path $RegPath -Force | Out-Null
            Log "Created new registry key: $RegPath"
        }

        # Set the lock screen image
        New-ItemProperty -Path $RegPath -Name LockScreenImagePath -Value $LockScreenPath -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $RegPath -Name LockScreenImageUrl -Value $LockScreenPath -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $RegPath -Name LockScreenImageStatus -Value 1 -PropertyType DWORD -Force | Out-Null

        Log "Lock screen image set successfully using PersonalizationCSP"

        # Optionally, we can still set the policy as well for additional enforcement
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "LockScreenImage" -Value $LockScreenPath -Force
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "NoChangingLockScreen" -Value 1 -Force
        Log "Lock screen policy set as additional enforcement"
    }
    catch {
        Log "Error setting lock screen image: $_"
    }
}
else {
    Log "Warning: Lock screen image file not found at $LockScreenPath"
}
#endregion
#region STEP 4 Set time zone (if specified)
# STEP 4: Set time zone (if specified)
if ($config.Config.TimeZone) {
    Log "Setting time zone: $($config.Config.TimeZone)"
    Set-Timezone -Id $config.Config.TimeZone
}
else {
    Log "Enabling location services for automatic time zone setting"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Type "String" -Value "Allow" -Force
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -Type "DWord" -Value 1 -Force
    Start-Service -Name "lfsvc" -ErrorAction SilentlyContinue
}
#endregion

#region STEP 5: Remove specified provisioned apps if they exist
Log "Removing specified in-box provisioned apps"
$apps = Get-AppxProvisionedPackage -online
$config.Config.RemoveApps.App | % {
    $current = $_
    $apps | ? { $_.DisplayName -eq $current } | % {
        try {
            Log "Removing provisioned app: $current"
            $_ | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
        }
        catch {
            Log "Failed to remove app $current. Error: $_"
        }
    }
}
#endregion
#region STEP 6: Install OneDrive per machine
# STEP 6: Install OneDrive per machine
if ($config.Config.OneDriveSetup) {
    Log "Downloading OneDriveSetup"
    $dest = "$($env:TEMP)\OneDriveSetup.exe"
    $client = new-object System.Net.WebClient
    $client.DownloadFile($config.Config.OneDriveSetup, $dest)
    Log "Installing: $dest"
    $proc = Start-Process $dest -ArgumentList "/allusers" -WindowStyle Hidden -PassThru
    $proc.WaitForExit()
    Log "OneDriveSetup exit code: $($proc.ExitCode)"
}
#endregion
#region STEP 7: Don't let Edge create a desktop shortcut (roams to OneDrive, creates mess)
# STEP 7: Don't let Edge create a desktop shortcut (roams to OneDrive, creates mess)
Log "Turning off (old) Edge desktop shortcut"
reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v DisableEdgeDesktopShortcutCreation /t REG_DWORD /d 1 /f /reg:64 | Out-Host
#endregion
#region STEP 8: Add language packs
# STEP 8: Add language packs
Log "Adding language packs"
Get-ChildItem "$($installFolder)LPs" -Filter *.cab | % {
    Log "Adding language pack: $($_.FullName)"
    Add-WindowsPackage -Online -NoRestart -PackagePath $_.FullName
}
#endregion
#region STEP 9: Change language
# STEP 9: Change language
if ($config.Config.Language) {
    Log "Configuring language using: $($config.Config.Language)"
    & $env:SystemRoot\System32\control.exe "intl.cpl,,/f:`"$($installFolder)$($config.Config.Language)`""
}
#endregion
#region STEP 10: Add features on demand
# STEP 10: Add features on demand
$currentWU = (Get-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -ErrorAction Ignore).UseWuServer
if ($currentWU -eq 1) {
    Log "Temporarily turning off WSUS"
    Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"  -Name "UseWuServer" -Value 0
    Restart-Service wuauserv
}
if ($config.Config.AddFeatures.Feature.Count -gt 0) {
    Log "Adding Windows features"
    $config.Config.AddFeatures.Feature | % {
        Log "Adding Windows feature: $_"
        Add-WindowsCapability -Online -Name $_ -ErrorAction SilentlyContinue | Out-Null
    }
}
if ($currentWU -eq 1) {
    Log "Turning WSUS back on"
    Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"  -Name "UseWuServer" -Value 1
    Restart-Service wuauserv
}
#endregion
#region STEP 11: Customize default apps
# STEP 11: Customize default apps
if ($config.Config.DefaultApps) {
    Log "Setting default apps: $($config.Config.DefaultApps)"
    & Dism.exe /Online /Import-DefaultAppAssociations:`"$($installFolder)$($config.Config.DefaultApps)`"
}
#endregion
#region STEP 12: Set registered user and organization
# STEP 12: Set registered user and organization
Log "Configuring registered user information"
reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v RegisteredOwner /t REG_SZ /d "$($config.Config.RegisteredOwner)" /f /reg:64 | Out-Host
reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v RegisteredOrganization /t REG_SZ /d "$($config.Config.RegisteredOrganization)" /f /reg:64 | Out-Host
#endregion
#region STEP 13: Configure OEM branding info
# STEP 13: Configure OEM branding info
if ($config.Config.OEMInfo) {
    Log "Configuring OEM branding info"

    reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" /v Manufacturer /t REG_SZ /d "$($config.Config.OEMInfo.Manufacturer)" /f /reg:64 | Out-Host
    reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" /v Model /t REG_SZ /d "$($config.Config.OEMInfo.Model)" /f /reg:64 | Out-Host
    reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" /v SupportPhone /t REG_SZ /d "$($config.Config.OEMInfo.SupportPhone)" /f /reg:64 | Out-Host
    reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" /v SupportHours /t REG_SZ /d "$($config.Config.OEMInfo.SupportHours)" /f /reg:64 | Out-Host
    reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" /v SupportURL /t REG_SZ /d "$($config.Config.OEMInfo.SupportURL)" /f /reg:64 | Out-Host
    Log "Copying OEM logo"
    Copy-Item "$installFolder\$($config.Config.OEMInfo.Logo)" "C:\Windows\$($config.Config.OEMInfo.Logo)" -Force
    reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" /v Logo /t REG_SZ /d "C:\Windows\$($config.Config.OEMInfo.Logo)" /f /reg:64 | Out-Host
}
#endregion
#region STEP 14: Enable UE-V
# STEP 14: Enable UE-V
Log "Enabling UE-V"
Enable-UEV
Set-UevConfiguration -Computer -SettingsStoragePath "%OneDriveCommercial%\UEV" -SyncMethod External -DisableWaitForSyncOnLogon
Get-ChildItem "$($installFolder)UEV" -Filter *.xml | % {
    Log "Registering UE-V template: $($_.FullName)"
    Register-UevTemplate -Path $_.FullName
}
#endregion
#region STEP 15: Disable network location fly-out
# STEP 15: Disable network location fly-out
Log "Turning off network location fly-out"
reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff" /f
#endregion
#region STEP 16: Disable new Edge desktop icon
# STEP 16: Disable new Edge desktop icon
Log "Turning off Edge desktop icon"
reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate" /v "CreateDesktopShortcutDefault" /t REG_DWORD /d 0 /f /reg:64 | Out-Host
#endregion
#region End logging
# End logging
Log "Script execution completed"
Stop-Transcript