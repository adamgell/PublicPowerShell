<# 
.SYNOPSIS 
Install New Microsoft Teams App on target devices 
.DESCRIPTION 
Below script will install New MS Teams App Offline.
 
.NOTES     
        Name       : New MS Teams App Installation Offline
        Author     : Jatin Makhija  
        Version    : 1.0.0  
        DateCreated: 12-Jan-2024
        Blog       : https://cloudinfra.net
         
.LINK 
https://cloudinfra.net 
#>
# Define paths and filenames
$msixFile = ".\MSTeams-x64.msix"
$destinationPath = "C:\windows\temp"
$bootstrapperPath = ".\teamsbootstrapper.exe"

# Copy MSTeams-x64.msix to the destination directory
Copy-Item -Path $msixFile -Destination $destinationPath -Force

# Check if the copy operation was successful
if ($?) {
    Get-AppPackage -AllUsers *MSTeams* | Remove-AppPackage -AllUsers -ErrorAction SilentlyContinue
    # Uninstall teams if perviously installed
    Start-Process -FilePath $bootstrapperPath -ArgumentList "-x" -Wait -WindowStyle Hidden
    # If successful, execute teamsbootstrapper.exe with specified parameters
    Start-Process -FilePath $bootstrapperPath -ArgumentList "-p", "-o", "$destinationPath\MSTeams-x64.msix" -Wait -WindowStyle Hidden
    Copy-Item -Path ".\teams.ico" -Destination "C:\ProgramData\Microsoft\teams.ico"
    
    # Create a shortcut on the public desktop
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut("C:\Users\Public\Desktop\Microsoft Teams.lnk")
    $shortcut.TargetPath = "EXPLORER.EXE"
    $shortcut.Arguments = "shell:AppsFolder\MSTeams_8wekyb3d8bbwe!MSTeams"
    $shortcut.IconLocation = "C:\ProgramData\Microsoft\teams.ico"
    $shortcut.Save()

    #copy to start menu
    $shortcut = $wshShell.CreateShortcut("C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Teams.lnk")
    $shortcut.TargetPath = "EXPLORER.EXE"
    $shortcut.Arguments = "shell:AppsFolder\MSTeams_8wekyb3d8bbwe!MSTeams"
    $shortcut.IconLocation = "C:\ProgramData\Microsoft\teams.ico"
    $shortcut.Save()

    Write-Host "Microsoft Teams installation completed successfully."
}
else {
    # If copy operation failed, display an error message
    Write-Host "Error: Failed to copy MSTeams-x64.msix to $destinationPath."
    exit 1
}