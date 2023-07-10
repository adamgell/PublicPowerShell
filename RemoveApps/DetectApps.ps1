<#
Version: 1.0
Author: 
- Joey Verlinden (joeyverlinden.com)
- Andrew Taylor (andrewstaylor.com)
- Florian Slazmann (scloud.work)
- Jannik Reinhard (jannikreinhard.com)
Script: Removes Search box in task bar
Description:
Hint: This is a community script. There is no guarantee for this. Please check thoroughly before running.
Version 1.0: Init
Run as: User/Admin
Context: 32 & 64 Bit
#> 
try {
    Start-Transcript -Path "$env:TEMP\$($(Split-Path $PSCommandPath -Leaf).ToLower().Replace(".ps1",".log"))" -Append
    $pathstoremove = "C:\Program Files\WindowsApps\Microsoft.MSPaint_1.0.46.0_x64__8wekyb3d8bbwe", "C:\Program Files\WindowsApps\Microsoft.WindowsTerminal_1.12.10983.0_x64__8wekyb3d8bbwe"
    $iftrue = $false
    foreach ($path in $pathstoremove) {
        if($iftrue -eq $true) {
            break; # break out of the loop if the path is found. this will run the remediation script.
        }
        Write-Host "Testing to see if $path exists ..."        
        $iftrue = Test-Path $path
    }
    if ($iftrue) {
        Write-Output "Not Compliant"
        Exit 1
    }
    else {
        Write-Output "Compliant"
        Exit 0
    } 
    Stop-Transcript | Out-Null
}
catch {
    Write-Host "An error occurred:"
    Write-Host $_
}
