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


$EncryptionData = Get-WmiObject -Namespace ROOT\CIMV2\Security\Microsoftvolumeencryption -Class Win32_encryptablevolume -Filter "DriveLetter = 'c:'"

$protectionState = $EncryptionData.GetConversionStatus()

$CurrentEncryptionProgress = $protectionState.EncryptionPercentage

switch ($ProtectionState.Conversionstatus) {

    "0" {

        $Properties = @{'EncryptionState' = 'FullyDecrypted'; 'CurrentEncryptionProgress' = $CurrentEncryptionProgress }

        $Return = New-Object psobject -Property $Properties

    }

    "1" {
        $Properties = @{'EncryptionState' = 'FullyEncrypted'; 'CurrentEncryptionProgress' = $CurrentEncryptionProgress }
        $Return = New-Object psobject -Property $Properties
    }

    "2" {
        $Properties = @{'EncryptionState' = 'EncryptionInProgress'; 'CurrentEncryptionProgress' = $CurrentEncryptionProgress }
        $Return = New-Object psobject -Property $Properties
    }

    "3" {

        $Properties = @{'EncryptionState' = 'DecryptionInProgress'; 'CurrentEncryptionProgress' = $CurrentEncryptionProgress }
        $Return = New-Object psobject -Property $Properties
    }

    "4" {
        $Properties = @{'EncryptionState' = 'EncryptionPaused'; 'CurrentEncryptionProgress' = $CurrentEncryptionProgress }
        $Return = New-Object psobject -Property $Properties
    }

    "5" {

        $Properties = @{'EncryptionState' = 'DecryptionPaused'; 'CurrentEncryptionProgress' = $CurrentEncryptionProgress }
        $Return = New-Object psobject -Property $Properties
    }

    default {
        write-verbose "Couldn't retrieve an encryption state."
        $Properties = @{'EncryptionState' = $false; 'CurrentEncryptionProgress' = $false }
        $Return = New-Object psobject -Property $Properties
    }

}

return $return1