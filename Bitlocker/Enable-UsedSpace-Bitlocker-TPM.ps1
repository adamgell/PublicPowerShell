$BitLockerOSVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive
$UsedSpace = manage-bde -status $ENV:SystemDrive | Select-String "Used Space Only Encrypted"

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
} else {
	Start-Encryption
}


