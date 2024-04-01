# Specify the drive letter to remove BitLocker from. For example, 'C:'
$DriveLetter = 'C:'

# Retrieve the BitLocker volume
$BitLockerVolume = Get-BitLockerVolume -MountPoint $DriveLetter

# Check if the volume is indeed protected by BitLocker
if ($BitLockerVolume.ProtectionStatus -eq 'On') {
    # Iterate over each key protector
    foreach ($KeyProtector in $BitLockerVolume.KeyProtector) {
        # Remove the key protector
        Remove-BitLockerKeyProtector -MountPoint $DriveLetter -KeyProtectorId $KeyProtector.KeyProtectorId
        Write-Host "Removed key protector: $($KeyProtector.KeyProtectorId)"
    }

    # Disable BitLocker, this will start the decryption process
    Disable-BitLocker -MountPoint $DriveLetter
    Write-Host "BitLocker is being disabled on $DriveLetter. Decryption is in progress..."
} else {
    Write-Host "BitLocker is not active on $DriveLetter."
}
