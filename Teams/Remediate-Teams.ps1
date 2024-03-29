<# 

.DESCRIPTION 
 remediate if Teams is installed
 ensure teams is loaded at startup.

#> 

# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64") {
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe") {
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy bypass -File "$PSCommandPath"
        Exit $lastexitcode
    }
}

$TempDir = (gi $env:temp).fullname
Start-Transcript "$TempDir\Remediate-Teams.log" -Append -Force -ErrorAction SilentlyContinue


try {
    #find teams.exe in localappdata
    $teams = Get-ChildItem -Path $env:LOCALAPPDATA\Microsoft\Teams -Filter Update.exe -Recurse -Force | Select-Object -First 1
    $teamsFullName = $teams.FullName
    $teamsDirectory = $teams.DirectoryName
    #find teams.exe in program files and start it so it installs to $localappdata
    $teamsProgramFiles = Get-ChildItem -Path ${env:ProgramFiles(x86)} -Filter Teams.exe -Recurse -Force -ErrorAction SilentlyContinue | Select-Object -First 1
    $teamsProgramFilesFullName = $teamsProgramFiles.FullName

    Write-Host "Found Teams.exe at $teamsFullName"
    if ($null -eq $teamsFullName) {
        Write-Host "Teams.exe not found"
        Write-Host "attempting to launch teams from the program files location"
        Start-Process $teamsProgramFilesFullName
    }
    
    Write-Host "Teams.exe found"
    
    #start teams
    Start-Process -FilePath $teams -ArgumentList "--processStart Teams.exe" -ErrorAction SilentlyContinue

    $Desktop = (Get-ItemProperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -name "Desktop").Desktop
    Write-Output $Desktop
    $shortcut = "$desktop\Teams.lnk"
    Write-Output $shortcut
    if (Test-Path $shortcut) {
        Write-Host "Teams shortcut already exists"
    }
    else {
        #create shortcut
        Write-Host "Teams shortcut does not exist, creating..."
        $WshShell = New-Object -comObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut("$shortcut")
        $Shortcut.TargetPath = "$teamsFullName"
        $Shortcut.Arguments = "--processStart Teams.exe"
        $Shortcut.WorkingDirectory = "$teamsDirectory"
        $Shortcut.Save()
    }

    #create tag file for win32 intune app detection rule
    if ($win32app) {
        # Create a tag file just so Intune knows this was installed
        if (-not (Test-Path "$($env:ProgramData)\Microsoft\RenameComputer")) {
            Mkdir "$($env:ProgramData)\Microsoft\RenameComputer"
        }
        Set-Content -Path "$($env:ProgramData)\Microsoft\RenameComputer\RenameComputer.ps1.tag" -Value "Installed"

    }
}
catch {
    #all errors are caught here
    Write-Host "Error: $_"
    exit 0
}

Stop-Transcript
