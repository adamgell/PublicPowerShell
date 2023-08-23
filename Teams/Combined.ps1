Param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Install", "Uninstall")]
    [String[]]$win32app
)

# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64") {
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe") {
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy bypass -File "$PSCommandPath"
        Exit $lastexitcode
    }
}

$TempDir = (gi $env:temp).fullname
Start-Transcript "$TempDir\Remediate-Teams.log" -Append -Force -ErrorAction SilentlyContinue

Write-Output $win32app
try {
    #find teams.exe in localappdata
    $teams = Get-ChildItem -Path $env:LOCALAPPDATA\Microsoft\Teams -Filter Update.exe -Recurse -Force -ErrorAction SilentlyContinue | Select-Object -First 1
    $teamsFullName = $teams.FullName
    $teamsDirectory = $teams.DirectoryName
    #find teams.exe in program files and start it so it installs to $localappdata
    $teamsProgramFiles = Get-ChildItem -Path ${env:ProgramFiles(x86)} -Filter Teams.exe -Recurse -Force -ErrorAction SilentlyContinue | Select-Object -First 1
    $teamsProgramFilesFullName = $teamsProgramFiles.FullName

    if ($null -eq $teams -or $null -eq $teamsProgramFiles) {
        Write-Host "Teams not found in localappdata or program files, exiting"
        Exit 1
    }


        
    #start teams
    
    Start-Process -FilePath $teamsFullName -ArgumentList "--processStart Teams.exe" -ErrorAction SilentlyContinue

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
        if ($win32app -eq "Install") {
            # Create a tag file just so Intune knows this was installed
            if (-not (Test-Path "$($teamsDirectory)")) {
                Mkdir "$($teamsDirectory)"
            }
            Set-Content -Path "$($teamsDirectory)\Teams.ps1.tag" -Value "Installed"
        }
        elseif ($win32app -eq "Uninstall") {
            Remove-Item "$($teamsDirectory)\Teams.ps1.tag"
        }
        else {
            Write-Host "Invalid parameter"
        }

    }
}
catch {
    #all errors are caught here
    $_
    Write-Host "Error: $_"
    exit 0
}

Stop-Transcript
