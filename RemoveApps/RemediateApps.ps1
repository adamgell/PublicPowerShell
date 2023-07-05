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

try {
    Start-Transcript -Path "$env:TEMP\$($(Split-Path $PSCommandPath -Leaf).ToLower().Replace(".ps1",".log"))" | Out-Null
    foreach ($path in $pathstoremove) {
        $pathstoremove = "C:\Program Files\WindowsApps\Microsoft.MSPaint_1.0.46.0_x64__8wekyb3d8bbwe","C:\Program Files\WindowsApps\Microsoft.WindowsTerminal_1.12.10983.0_x64__8wekyb3d8bbwe"
        Write-Host "Removing $path"
        Remove-AppxProvisionedPackage -Online -PackageName $path -AllUsers | Out-Null
        Remove-AppxProvisionedPackage -Online -Package $path | Out-Null
    }
    Stop-Transcript | Out-Null
}   
catch {
    Write-Output $_.ErrorDetails
    exit 0
}
