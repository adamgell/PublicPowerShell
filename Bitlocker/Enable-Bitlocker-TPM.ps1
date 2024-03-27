Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -TpmProtector
Enable-BitLocker -MountPoint $env:SystemDrive -RecoveryPasswordProtector -SkipHardwareTest
Start-Sleep -Seconds 15
$KEY = Get-BitLockerVolume -MountPoint "C:"
Backup-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $KEY.KeyProtector[1].KeyProtectorId
