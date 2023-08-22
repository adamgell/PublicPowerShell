<# 

.DESCRIPTION 
 Detect if Teams is installed
 if not, it will cleanly exit. 

 If its detected, it will run a remediate script to ensure teams is loaded at startup.

#> 

# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64") {
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe") {
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy bypass -File "$PSCommandPath"
        Exit $lastexitcode
    }
}

Start-Transcript "$env:Temp\Detect-Teams.log" -Append

#find teams.exe in localappdata
try {
    $teams = Get-ChildItem -Path $env:LOCALAPPDATA\Microsoft\Teams -Filter Update.exe -Recurse -Force | Select-Object -First 1
    $teamsFullName = $teams.FullName

    Write-Output "Found Teams.exe at $teamsFullName"
    if ($null -eq $teamsFullName) {
        Write-Output "Teams.exe not found - something is wrong and teams is not installed??"
        exit 1
    } 
    else {
        Write-Output "Teams.exe found"
        exit 0
    }
}
catch {
    #all errors are caught here
    Write-Output "Error: $_"
    exit 1
}

Stop-Transcript
