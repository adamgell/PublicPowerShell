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
$regname = "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}"

##Enter the value of the registry key we are checking for, for example 0
$regvalue = "1"


Try {
    $Registry = Get-ItemProperty -Path $regpath -Name $regname -ErrorAction Stop | Select-Object -ExpandProperty $regname
    If ($Registry -eq $regvalue){
        Write-Output "Compliant"
        Exit 0
    } 
    Write-Warning "Not Compliant"
    Exit 1
} 
Catch {
    Write-Warning "Not Compliant"
    Exit 1
}
