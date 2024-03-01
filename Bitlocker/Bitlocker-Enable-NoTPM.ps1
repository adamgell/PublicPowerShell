$BitLockerOSVolume = Get-BitLockerVolume -MountPoint $env:SystemRoot
if (($BitLockerOSVolume.VolumeStatus -like "FullyEncrypted") -and ($BitLockerOSVolume.KeyProtector.KeyProtectorType -eq "Password")) {
	Write-Host "Drive already encrypted and has a password protector"
} else {
	$SecureString = ConvertTo-SecureString "testing123!" -AsPlainText -Force
	Enable-BitLocker -MountPoint "C:" -Skiphardwaretest -PasswordProtector $SecureString
}
