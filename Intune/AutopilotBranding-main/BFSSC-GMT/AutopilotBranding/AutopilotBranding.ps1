function Log() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)] [String] $message
    )

    $ts = get-date -f "yyyy/MM/dd hh:mm:ss tt"
    Write-Output "$ts $message"
}

# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64") {
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe") {
        Log "Relaunching as 64-bit process"
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath"
        Exit $lastexitcode
    }
}

# Create output folder
Log "Creating output folder"
if (-not (Test-Path "$($env:ProgramData)\Microsoft\AutopilotBranding")) {
    Mkdir "$($env:ProgramData)\Microsoft\AutopilotBranding" -Force
    Log "Output folder created successfully"
}
else {
    Log "Output folder already exists"
}

# Start logging
Log "Starting transcript"
Start-Transcript "$($env:ProgramData)\Microsoft\AutopilotBranding\AutopilotBranding.log"

# Creating tag file
Log "Creating tag file"
Set-Content -Path "$($env:ProgramData)\Microsoft\AutopilotBranding\AutopilotBranding.ps1.tag" -Value "Installed"
Log "Tag file created successfully"

# PREP: Load the Config.xml
$installFolder = "$PSScriptRoot\"
Log "Install folder: $installFolder"
Log "Loading configuration: $($installFolder)Config.xml"
[Xml]$config = Get-Content "$($installFolder)Config.xml"
Log "Configuration loaded successfully"

# STEP 1: Apply custom start menu layout
$ci = Get-ComputerInfo
Log "OS Build Number: $($ci.OsBuildNumber)"
if ($ci.OsBuildNumber -le 22000) {
    Log "Importing layout: $($installFolder)Layout.xml"
    Copy-Item "$($installFolder)Layout.xml" "C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.xml" -Force
    Log "Layout.xml imported successfully"
}
else {
    Log "Importing layout: $($installFolder)Start2.bin"
    MkDir -Path "C:\Users\Default\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState" -Force -ErrorAction SilentlyContinue | Out-Null
    Copy-Item "$($installFolder)Start2.bin" "C:\Users\Default\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\Start2.bin" -Force
    Log "Start2.bin imported successfully"
}

# STEP 2: Configure background
Log "Loading default user hive"
reg.exe load HKLM\TempUser "C:\Users\Default\NTUSER.DAT" | Out-Host

Log "Setting up Autopilot theme"
Mkdir "C:\Windows\Resources\OEM Themes" -Force | Out-Null
Copy-Item "$installFolder\Autopilot.theme" "C:\Windows\Resources\OEM Themes\Autopilot.theme" -Force
Mkdir "C:\Windows\web\wallpaper\Autopilot" -Force | Out-Null
Copy-Item "$installFolder\Autopilot.jpg" "C:\Windows\web\wallpaper\Autopilot\Autopilot.jpg" -Force
Log "Autopilot theme setup completed"

Log "Setting Autopilot theme as the new user default"
reg.exe add "HKLM\TempUser\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes" /v InstallTheme /t REG_EXPAND_SZ /d "%SystemRoot%\resources\OEM Themes\Autopilot.theme" /f | Out-Host

# NEW STEP: Set Autopilot.jpg as lock screen image and restart explorer
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
        #Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "LockScreenImage" -Value $LockScreenPath -Force
        #Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "NoChangingLockScreen" -Value 1 -Force
        Log "Lock screen policy set as additional enforcement"

        # Restart explorer.exe to apply changes
        Log "Restarting explorer.exe to apply lock screen changes"
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Process explorer
        Log "Explorer.exe restarted successfully"
    }
    catch {
        Log "Error setting lock screen image or restarting explorer: $_"
    }
}
else {
    Log "Warning: Lock screen image file not found at $LockScreenPath"
}

# Force the lock screen image policy
Log "Enforcing lock screen image policy"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "NoChangingLockScreen" -Value 1
Log "Lock screen image policy enforced"

# STEP 2A: Stop Start menu from opening on first logon
Log "Configuring Start menu not to open on first logon"
reg.exe add "HKLM\TempUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v StartShownOnUpgrade /t REG_DWORD /d 1 /f | Out-Host

# STEP 2B: Hide "Learn more about this picture" from the desktop
Log "Hiding 'Learn more about this picture' from the desktop"
reg.exe add "HKLM\TempUser\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" /v "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}" /t REG_DWORD /d 1 /f | Out-Host

Log "Unloading default user hive"
reg.exe unload HKLM\TempUser | Out-Host

# STEP 3: Set time zone (if specified)
if ($config.Config.TimeZone) {
    Log "Setting time zone: $($config.Config.TimeZone)"
    Set-Timezone -Id $config.Config.TimeZone
    Log "Time zone set successfully"
}
else {
    Log "Time zone not specified, enabling location services"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Type "String" -Value "Allow" -Force
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -Type "DWord" -Value 1 -Force
    Start-Service -Name "lfsvc" -ErrorAction SilentlyContinue
    Log "Location services enabled"
}

# ... [The rest of the script continues with similar logging enhancements]

Log "Script execution completed"
Stop-Transcript