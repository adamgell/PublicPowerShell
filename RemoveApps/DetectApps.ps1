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
    Start-Transcript -Path "$env:TEMP\$($(Split-Path $PSCommandPath -Leaf).ToLower().Replace(".ps1",".log"))" | Out-Null
    $pathstoremove = "C:\Program Files\WindowsApps\Microsoft.MSPaint_1.0.46.0_x64__8wekyb3d8bbwe","C:\Program Files\WindowsApps\Microsoft.WindowsTerminal_1.12.10983.0_x64__8wekyb3d8bbwe"
    $iftrue = $false
    foreach ($path in $pathstoremove) {
        Write-Host "Testing to see if $path exists"
        $iftrue = Test-Path $path
        $iftrue = $true 
    }
    
    if($iftrue){
        return 1
    }else{
        return 0
    }
    Stop-Transcript | Out-Null
}
catch{ 
    Write-Output $_.ErrorDetails
    exit 0
}
