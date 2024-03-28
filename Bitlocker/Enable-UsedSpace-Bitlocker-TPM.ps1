$BitLockerOSVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive
$managebde = manage-bde -status $ENV:SystemDrive
$UsedSpace = $managebde | Select-String -Pattern "Used Space Only Encrypted"
$FullyEncrypted = $managebde | Select-String -Pattern "Fully Encrypted"

function Start-Encryption {
    Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -TpmProtector
    Enable-BitLocker -MountPoint $env:SystemDrive -RecoveryPasswordProtector -SkipHardwareTest
    Start-Sleep -Seconds 15
    Backup-BitLockerKeyProtector -MountPoint $env:SystemDrive -KeyProtectorId $BitLockerOSVolume.KeyProtector[1].KeyProtectorId
}

if (($BitLockerOSVolume.VolumeStatus -like "FullyEncrypted") -and ($null -ne $UsedSpace)) {
    Write-Host "Drive already encrypted under used space only. Let's remove this encryption and re-encrypt with full disk encryption."
    Disable-BitLocker -MountPoint $env:SystemDrive
    Start-Sleep -Seconds 120
    Start-Encryption
}
elseif ($null -ne $FullyEncrypted) {
    Write-Host "Drive already full encrypted. Exiting."
}else { 
    Start-Encryption
}


