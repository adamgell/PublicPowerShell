#Copy necessary files from intunewin package to local PC
$resourcePath = "C:\ProgramData\IntuneIcons"

if (!(Test-Path $resourcePath)) {
	mkdir $resourcePath
}

$packageFiles = @(
    "file.ico",
)

foreach ($file in $packageFiles) {
	Copy-Item -Path "$($PSScriptRoot)\$($file)" -Destination "$($resourcePath)" -Force -Verbose
}

$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\Arkansas State Library.lnk")
#url
$Shortcut.TargetPath=""
$Shortcut.Arguments=""
#icon
$Shortcut.IconLocation="$resourcePath\file.ico"
$Shortcut.Save()
