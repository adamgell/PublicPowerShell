
$BitLockerOSVolume = Get-BitLockerVolume -MountPoint $env:SystemRoot

function Start-Encryption {
    Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -TpmProtector
    Enable-BitLocker -MountPoint $env:SystemDrive -RecoveryPasswordProtector -SkipHardwareTest
    Start-Sleep -Seconds 15
    $KEY = Get-BitLockerVolume -MountPoint $env:SystemRoot
    Backup-BitLockerKeyProtector -MountPoint $env:SystemRoot -KeyProtectorId $KEY.KeyProtector[1].KeyProtectorId
}

if (($BitLockerOSVolume.VolumeStatus -like "FullyEncrypted") -and ($BitLockerOSVolume.ProtectionStatus -eq "on")) {
	Write-Host "Drive already encrypted under used space only. Let's remove this encryption and re-encrypt with full disk encryption."
    Disable-BitLocker -MountPoint $env:SystemRoot
    Start-Sleep -Seconds 120
    Start-Encryption
} else {
	Start-Encryption
}


