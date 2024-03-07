Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -TpmProtector
Enable-BitLocker -MountPoint $env:SystemDrive -RecoveryPasswordProtector -SkipHardwareTest
