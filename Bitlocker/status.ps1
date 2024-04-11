$BitLockerDecrypted = (Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue).VolumeStatus
# Check Bitlocker status states
switch ($BitLockerDecrypted) {
    "FullyDecrypted" {
        Write-Host "Bitlocker volume is fully decrypted"
    }
    "EncryptionInProgress" {
        Write-Host "Bitlocker volume encryption is in progress. Stopping at this point."
    }
    "DecryptionInProgress" {
        Write-Host "Bitlocker volume decryption is in progress. Stopping at this point"
    }
    "FullyEncrypted" {
       Write-Host "Bitlocker volume is already encrypted. Stopping at this point."
    }
}