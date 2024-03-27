$BitLockerOSVolume = Get-BitLockerVolume -MountPoint $env:SystemRoot
if (($BitLockerOSVolume.VolumeStatus -like "FullyEncrypted") -and ($BitLockerOSVolume.KeyProtector.KeyProtectorType -eq "Password")) {
	Write-Host "Drive already encrypted and has a password protector"
} else {
	$SecureString = ConvertTo-SecureString "testing123!" -AsPlainText -Force
	Enable-BitLocker -MountPoint "C:" -Skiphardwaretest -PasswordProtector $SecureString
	Start-Sleep -Seconds 15
	$KEY = Get-BitLockerVolume -MountPoint "C:"
	Backup-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $KEY.KeyProtector[1].KeyProtectorId

}

