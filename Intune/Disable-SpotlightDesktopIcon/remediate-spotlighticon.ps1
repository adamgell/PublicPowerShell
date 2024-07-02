<#
Version: 1.0
Author: 
- Adam Gell (https://github.com/adamgell)
Script: remediate-fastboot.ps1
Description: Disables Spotlight icon on Windows desktop
https://oofhours.com/2024/06/01/getting-rid-of-the-learn-about-this-picture-icon-on-the-windows-11-desktop/
Release notes:
Version 1.0: Init
Run as: Admin/User
Context: 64 Bit
#> 
##Enter the path to the registry key for example HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System
$regpath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"

##Enter the name of the registry key for example EnableLUA
$regname = '{2cc5ca98-6485-489a-920e-b3e88a6ccce3}'

##Enter the value of the registry key we are checking for, for example 0
$regvalue = "1"
##Enter the type of the registry key for example DWord
$regtype = "DWord"


$advancedrun_link = "https://www.nirsoft.net/utils/advancedrun-x64.zip"
$advancedrun_zip = "$env:TEMP\advancedrun-x64.zip"
$advancedrun_folder = "$env:TEMP\advancedrun-x64"
$advancedrun_exe = "$advancedrun_folder\AdvancedRun.exe"
#download and extract AdvancedRun
Invoke-WebRequest -Uri $advancedrun_link -OutFile $advancedrun_zip
Expand-Archive -Path $advancedrun_zip -DestinationPath $advancedrun_folder -Force

#AdvancedRun.exe /EXEFilename "c:\windows\system32\cmd.exe" /RunAs 8 /Run
$scriptblock = "New-ItemProperty -LiteralPath $regpath -Name $regname -Value $regvalue -PropertyType $regtype -Force -ea Continue"

#Remove-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" -Name '{2cc5ca98-6485-489a-920e-b3e88a6ccce3}' -Force -ErrorAction Continue
& $advancedrun_exe /CommandLine "$scriptblock" /RunAs 4 /Run
