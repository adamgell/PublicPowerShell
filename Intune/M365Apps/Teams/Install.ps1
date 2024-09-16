# Define paths and filenames
$msixFile = ".\MSTeams-x64.msix" # Path to the Microsoft Teams MSIX package file
$destinationPath = "C:\windows\temp" # Destination directory where the MSIX file will be copied
$bootstrapperPath = ".\teamsbootstrapper.exe" # Path to the Teams bootstrapper executable

# Copy MSTeams-x64.msix to the destination directory
Copy-Item -Path $msixFile -Destination $destinationPath -Force

# Check if the copy operation was successful
if ($?) {
    # Uninstall any previously installed Microsoft Teams packages for all users
    Get-AppPackage -AllUsers *MSTeams* | Remove-AppPackage -AllUsers -ErrorAction SilentlyContinue
    
    # If successful, execute the bootstrapper to perform cleanup operations
    Start-Process -FilePath $bootstrapperPath -ArgumentList "-x" -Wait -WindowStyle Hidden

    # Execute the bootstrapper again to install the MSIX package from the specified destination path
    Start-Process -FilePath $bootstrapperPath -ArgumentList "-p", "-o", "$destinationPath\MSTeams-x64.msix" -Wait -WindowStyle Hidden

    # Copy the Teams icon to the ProgramData directory for use in shortcuts
    Copy-Item -Path ".\teams.ico" -Destination "C:\ProgramData\Microsoft\teams.ico"
    
    # Create a shortcut on the public desktop
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut("C:\Users\Public\Desktop\Microsoft Teams.lnk")
    $shortcut.TargetPath = "EXPLORER.EXE" # Set the shortcut target to open Explorer
    $shortcut.Arguments = "shell:AppsFolder\MSTeams_8wekyb3d8bbwe!MSTeams" # Arguments to launch the Teams app
    $shortcut.IconLocation = "C:\ProgramData\Microsoft\teams.ico" # Set the Teams icon for the shortcut
    $shortcut.Save()

    # Copy the shortcut to the Start Menu for all users
    $shortcut = $wshShell.CreateShortcut("C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Teams.lnk")
    $shortcut.TargetPath = "EXPLORER.EXE" # Set the shortcut target to open Explorer
    $shortcut.Arguments = "shell:AppsFolder\MSTeams_8wekyb3d8bbwe!MSTeams" # Arguments to launch the Teams app
    $shortcut.IconLocation = "C:\ProgramData\Microsoft\teams.ico" # Set the Teams icon for the shortcut
    $shortcut.Save()

    # Indicate successful installation
    Write-Host "Microsoft Teams installation completed successfully."
}
else {
    # If the copy operation failed, display an error message and exit with error code
    Write-Host "Error: Failed to copy MSTeams-x64.msix to $destinationPath."
    exit 1
}
