<#
Version: 1.0
Author: 
- Joey Verlinden (joeyverlinden.com)
- Andrew Taylor (andrewstaylor.com)
- Florian Slazmann (scloud.work)
- Jannik Reinhard (jannikreinhard.com)
Script: Get-TemplateRemediation
Description:
Hint: This is a community script. There is no guarantee for this. Please check thoroughly before running.
Version 1.0: Init
Run as: User/Admin
Context: 32 & 64 Bit
#> 

<#
Computer\HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\PackageRepository\Packages\Microsoft.Microsoft3DViewer_2.1803.8022.0_neutral_~_8wekyb3d8bbwe
Get-AppxPackage -allusers *Microsoft.WebpImageExtension * | Remove-AppxPackage –AllUsers
Get-AppxProvisionedPackage –online | where-object {$_.packagename –like "PackageName"} | Remove-AppxProvisionedPackage –online
#>
$ErrorActionPreference = 'Continue'

Start-Transcript -Path "$env:TEMP\$($(Split-Path $PSCommandPath -Leaf).ToLower().Replace(".ps1",".log"))" -Append
$pathstoremove = "C:\Program Files\WindowsApps\Microsoft.MSPaint_1.0.46.0_x64__8wekyb3d8bbwe", "C:\Program Files\WindowsApps\Microsoft.WindowsTerminal_1.12.10983.0_x64__8wekyb3d8bbwe"
foreach ($path in $pathstoremove) {
    $app = Split-Path -Path $path -Leaf
    Write-Host "Querying for Application ... $app"
    Remove-AppxProvisionedPackage -Online -PackageName $path -AllUsers
    Remove-AppxProvisionedPackage -Online -Package $path 
    Get-AppxPackage -AllUsers | Where-Object { $_.PackageFullName -eq "$app" } | Remove-AppxPackage -AllUsers
    Get-AppxPackage -AllUsers | Where-Object { $_.PackageFullName -eq "$app" } | Remove-AppxPackage 
}
Stop-Transcript | Out-Null





