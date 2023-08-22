#find teams.exe in localappdata
try {
    $teams = Get-ChildItem -Path $env:LOCALAPPDATA\Microsoft\Teams -Filter Update.exe -Recurse -Force | Select-Object -First 1
    $teamsFullName = $teams.FullName
    $teamsDirectory = $teams.DirectoryName
    Write-Host "Found Teams.exe at $teamsFullName"
    if ($teamsFullName -eq $null) {
        Write-Host "Teams.exe not found"
        exit 0
    }
    else {
        Write-Host "Teams.exe found"
    
        #start teams
        Start-Process -FilePath $teams -ArgumentList "--processStart Teams.exe" -ErrorAction SilentlyContinue

        $shortcut = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Teams.lnk"
        if (Test-Path $shortcut) {
            Write-Host "Teams shortcut already exists"
        }
        else {
            #create shortcut
            Write-Host "Teams shortcut does not exist, creating..."
            $WshShell = New-Object -comObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Teams.lnk")
            $Shortcut.TargetPath = "$teams"
            $Shortcut.Arguments = "--processStart Teams.exe"
            $Shortcut.WorkingDirectory = "$teamsDirectory"
            $Shortcut.Save()
        }
    }
}
catch {
    #all errors are caught here
    Write-Host "Error: $_"
}


