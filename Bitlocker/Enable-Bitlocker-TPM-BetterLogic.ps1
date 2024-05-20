# Bitlocker Sample Script
# Version 0.5

#
# Write-Log function
#
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Severity,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message
    )

    $computername = $env:COMPUTERNAME

    [pscustomobject]@{
        Time     = (Get-Date -Format "yyyy-MM-dd HH:mm")
        Severity = $Severity
        Message  = $Message
    } | Export-Csv -Path "C:\Bitlocker\LogFile_$computername.csv" -Append -NoTypeInformation
}

#
# Variables declaration
#
$FirmwareType = $env:firmware_type
$OSArchitecture = (Get-CimInstance -ClassName CIM_OperatingSystem).OSArchitecture 
$OSReleaseId = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ReleaseId
$TPMPresent = [bool](Get-WmiObject -class WIN32_TPM -Namespace root\CIMv2\Security\Microsofttpm).IsEnabled_InitialValue
$TPMReady = [bool](Get-WmiObject -class WIN32_TPM -Namespace root\CIMv2\Security\Microsofttpm).IsActivated_InitialValue
$BitLockerReadyDrive = (Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue).MountPoint 
$BitLockerDecrypted = (Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue).VolumeStatus

$managebde = manage-bde -status $ENV:SystemDrive
$UsedSpace = $managebde | Select-String -Pattern "Used Space Only Encrypted"

$bitlockerfolder = "C:\Bitlocker"
if (!(Test-Path $bitlockerfolder)) {
    New-Item -Path $bitlockerfolder -ItemType Directory
}

# Define exit codes
$Error_Success = 0
$Error_OsLegacy = 10
$Error_Os32Bit = 11
$Error_OsReleaseId = 12
$Error_TpmNotPreent = 20
$Error_TpmNotReady = 21
$Error_BLDriveNotReady = 30
$Error_BLEncryptionInProgress = 31
$Error_BLDecryptionInProgress = 32
$Error_BLFullyEncrypted = 32

# Check if boot mode is UEFI or LEGACY
if ($FirmwareType -ne "UEFI") {
    Write-Host "OS Boot Mode is LEGACY."
    Write-Host "TPM is not supported with this Boot Mode."
    Write-Log -Message "OS Boot Mode is LEGACY." -Severity Error
    Write-Log -Message "TPM is not supported with this Boot Mode." -Severity Error
    Exit $Error_OsLegacy
}
else {
    Write-Host "OS boot mode is UEFI"
    Write-Log -Message "OS boot mode is UEFI" -Severity Info
}

# Check if architecture is 32 Bit or 64 Bit
if ($OSArchitecture -ne "64-bit") {
    Write-Host "OS architecture is 32 bit"
    Write-Host "TPM is not supported with this OS architecture"
    Write-Log -Message "OS architecture is 32 bit" -Severity Error
    Write-Log -Message "TPM is not supported with this OS architecture" -Severity Error
    Exit $Error_Os32Bit
}
else {
    Write-Host "OS architecture is 64 bit"
    Write-Log -Message "OS architecture is 64 bit" -Severity Info
}

# Check if OS release id is supported (below 1809 is not supported)
if ($OSReleaseId -lt '1809') {
    Write-Host "OS ReleaseId is lower than 1809 and will not be supported"
    Write-Log -Message "OS ReleaseId is lower than 1809 and will not be supported" -Severity Error
    Exit $Error_OsReleaseId
}
else {
    Write-Host "OS ReleaseId is supported."
    Write-Log -Message "OS ReleaseId is supported." -Severity Info
}

# Check if TPMPresent is true
if (!$TPMPresent) {
    Write-Host "TPM is not present. Please check the BIOS settings (Trusted Platform)"
    Write-Log -Message "TPM is not present. Please check the BIOS settings (Trusted Platform)" -Severity Error
    Exit $Error_TpmNotPreent    
}
else {
    Write-Host "TPM is present"
    Write-Log -Message "TPM is present" -Severity Info
}

# Check if TPM is ready
if (!$TPMReady) {
    Write-Host "TPM is not ready"
    Write-Log -Message "TPM is not ready" -Severity Error
    Exit $Error_TpmNotReady  
}
else {
    Write-Host "TPM is ready"
    Write-Log -Message "TPM is ready" -Severity Info
}

# Check if MountPoint exists
if (!$BitLockerReadyDrive) {
    Write-Host "Bitlocker MountPoint does not exist"
    Write-Log -Message "Bitlocker MountPoint does not exist" -Severity Error
    Exit $Error_BLDriveNotReady      
}
else {
    Write-Host "Bitlocker MountPoint exists"
    Write-Log -Message "Bitlocker MountPoint exists" -Severity Info
}


function InitializeTpm {
    # Initialize TPM, add recovery partition if needed and enable Bitlocker
    Initialize-Tpm -AllowClear -AllowPhysicalPresence
    BdeHdCfg -target $env:SystemDrive shrink -quiet
    Enable-BitLocker -MountPoint $env:SystemDrive -RecoveryPasswordProtector -SkipHardwareTest -UsedSpaceOnly:$false
    Write-Log -Message "TPM initialized, recovery partition added if needed and Bitlocker enabled." -Severity Info
    
    while ((Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue).VolumeStatus -eq "EncryptionInProgress") {
        Write-Host "Encryption is in progress..."
        Write-Host "Drive $drive is encrypting. Checking again in 60 seconds."
        Start-Sleep -Seconds 60
        if ((Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue).VolumeStatus -eq "FullyEncrypted") {
            Write-Host "Encryption is done"
            Write-Log -Message "Encryption is done" -Severity Warning
        }
    }

    Start-Sleep -Seconds 120
    
    if ((Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue).ProtectionStatus -eq "Off") {
        Write-Host "Protection status is off. Enabling it."
        Write-Log -Message "Protection status is off. Enabling it." -Severity Warning
        Resume-BitLocker -MountPoint $env:SystemDrive
    }
    else {
        Write-Host "Protection status is on."
        Write-Log -Message "Protection status is on." -Severity Info
    }

}

# Add Bitlocker Protectors
function AddBitlockerProtectors {
    # Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -TpmProtector -ErrorAction SilentlyContinue
    # Write-Log -Message "Adding Bitlocker TpmProtector" -Severity Info
    # Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -RecoveryPasswordProtector -ErrorAction SilentlyContinue
    # Write-Log -Message "Adding Bitlocker RecoveryPasswordProtector" -Severity Info
}

$BT_TAG = Test-Path "C:\ProgramData\Bitlocker\Bitlocker-Reencrypt.tag"
$encryptMethod = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\FVE' -Name 'OSEncryptionType' | select -ExpandProperty OSEncryptionType

if ($encryptMethod -eq 2) {
    Write-Host "Encryption method is set to used space only."
    Write-Log -Message "Encryption method is set to used space only." -Severity Info
} else {
    Write-Host "Encryption method is set to full disk encryption."
    Write-Log -Message "Encryption method is set to full disk encryption." -Severity Info
}


# Check Bitlocker status states
switch ($BitLockerDecrypted) {
    "FullyDecrypted" {
        Write-Host "Bitlocker volume is fully decrypted"
        Write-Log -Message "Bitlocker volume is fully decrypted" -Severity Info
        InitializeTpm
        # AddBitlockerProtectors
    }
    "EncryptionInProgress" {
        Write-Host "Bitlocker volume encryption is in progress. Stopping at this point."
        Write-Log -Message "Bitlocker volume encryption is in progress. Stopping at this point." -Severity Error
        Exit $Error_BLEncryptionInProgress
    }
    "DecryptionInProgress" {
        Write-Host "Bitlocker volume decryption is in progress. Stopping at this point"
        Write-Log -Message "Bitlocker volume decryption is in progress. Stopping at this point" -Severity Error
         try {
            while ($true) {

                $drive = "C:"
                # Get BitLocker status
                $VolumeStatus = Get-BitLockerVolume -MountPoint $drive | Select VolumeStatus
                
                if ($VolumeStatus -match "FullyDecrypted") {
                    Write-Host "Drive $drive is fully Decrypted."
                    break # Exit loop
                }
                else {
                    Write-Host "Drive $drive is decrypting. Checking again in 60 seconds."
                    Start-Sleep -Seconds 60 # Wait for 60 seconds before checking again
                }
            }

            Write-Host "Encryption check complete."
        }
        catch {
            Write-Host "Error disabling Bitlocker. Stopping at this point."
            Write-Log -Message "Error disabling Bitlocker. Stopping at this point." -Severity Error
            Exit $Error_BLDecryptionInProgress
        } 
    }
    "FullyEncrypted" {
        if (($null -ne $UsedSpace) -and ($BT_TAG -eq $false) -and ($encryptMethod -eq 1)) {
            Write-Host "Drive already encrypted under used space only. Let's remove this encryption and re-encrypt with full disk encryption."
            Disable-BitLocker -MountPoint $env:SystemDrive
            Start-Sleep -Seconds 120
            InitializeTpm
            #creats a tag file to prevent re-encryption loop.
            New-Item -Path "C:\ProgramData\Bitlocker" -ItemType Directory -ErrorAction SilentlyContinue
            New-item -Path "C:\ProgramData\Bitlocker\Bitlocker-Reencrypt.tag" -ItemType File -ErrorAction SilentlyContinue
            # AddBitlockerProtectors
        }
        else {
            Write-Host "Bitlocker volume is already encrypted. Stopping at this point."
            Write-Log "Bitlocker volume is already encrypted. Stopping at this point." -Severity Error
            Exit $Error_BLFullyEncrypted
        }
    }
    default {
        Write-Host "Bitlocker volume is in an unknown state. Stopping at this point."
        Write-Log -Message "Bitlocker volume is in an unknown state. Stopping at this point." -Severity Error
        Exit $Error_BLDriveNotReady
    }
}

# Finish
Write-Host
Write-Host "Bitlocker has been successfully enabled. Encryption started."
Write-Log -Message "Bitlocker has been successfully enabled. Encryption started." -Severity Info
Exit $Error_Success