# RenameComputer
Sample app for renaming a Hybrid Azure AD joined (AD-joined) device after an Autopilot deployment.  Note that you will probably want to customize the RenameComputer.ps1 script to add your own naming logic, then build a new RenameComputer.intunewin package by running the "makeapp.cmd" file from a command prompt.

To set up the RenameComputer app in Intune, perform the following steps.

Add the UpdateOS.intunewin app to Intune and specify the following command line:

powershell.exe -noprofile -executionpolicy bypass -file .\RenameComputer.ps1

To "uninstall" the app, the following can be used (for example, to get the app to re-install):

cmd.exe /c del %ProgramData%\Microsoft\RenameComputer\RenameComputer.ps1.tag

Specify the platforms and minimum OS version that you want to support.

For a detection rule, specify the path and file and "File or folder exists" detection method:

%ProgramData%\Microsoft\RenameComputer RenameComputer.ps1.tag

Deploy the app as a required app to an appropriate set of devices.