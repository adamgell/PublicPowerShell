# Author: Joymalya Basu Roy
# Purpose: To convert existing 128-bit used-space only Bitlocker encrypted volumes to 256-bit full encryption Bitlocker protected volumes on the Chess 2 PCs.
# Name: bitlocker.ps1


<# Section - Function for TPM ownership Detection and Remediation  #>
Function DetectRemediateTPMOwnership()
{ 
     Write-Output "Performing TPM check to see if it's owned..."

        try {
             # Check if TPM chip is currently owned, if not take ownership
             $TPMClass = Get-WmiObject -Namespace "root\cimv2\Security\MicrosoftTPM" -Class "Win32_TPM"
             $IsTPMOwned = $TPMClass.IsOwned().IsOwned
             if ($IsTPMOwned -eq $false) 
                 {
                    Write-Output "TPM chip is currently not owned, value from WMI class method 'IsOwned' was: $($IsTPMOwned)"
        
                        # Generate a random pass phrase to be used when taking ownership of TPM chip
                        $NewPassPhrase = (New-Guid).Guid.Replace("-", "").SubString(0, 14)
        
                        # Construct owner auth encoded string
                        $NewOwnerAuth = $TPMClass.ConvertToOwnerAuth($NewPassPhrase).OwnerAuth
        
                        # Attempt to take ownership of TPM chip
                        $Invocation = $TPMClass.TakeOwnership($NewOwnerAuth)

                            if ($Invocation.ReturnValue -eq 0) {
                                Write-Output "TPM chip ownership was successfully taken"
                               }
                               else {
                                Write-Output "Failed to take ownership of TPM chip, return value from invocation: $($Invocation.ReturnValue)"
                               }
                 }
                 else 
                 {
                      Write-Output "TPM chip is currently owned, will not attempt to take ownership"
                 }
             }
        catch [System.Exception] {
             Write-Output "An error occurred while taking ownership of TPM chip. Error message: $($_.Exception.Message)"
        }
}

<# Section - Function for Removable Storage Media Detection and Remediation #>
Function DetectRemediateRemovableMedia()
{
    Write-Output "Performing checks to see if there are removable storage drives and/or ISO/disk attached ..."
        
        # Detect and Eject all optical drive(s) and/or mounted ISO
        try
        {
                $sh = New-Object -ComObject "Shell.Application"
				$items = $sh.namespace(17).Items()
				ForEach($item in $items)
				{
					If($item.type -eq "CD Drive")
					{
						Write-Output "Media in Optical Drive detected"
                        Write-Output "Invoking Eject..."
                        $item.InvokeVerb("Eject")
                        Write-Output "Ejected successfully"
					}
				}
        }
        catch [System.Exception]{
                Write-Output "An error occurred while attempting to Eject ISO/DVD media. Error message: $($_.Exception.Message)"
        }

        # Detect and Eject all Removable USB storage, if found...
        try
        {
                $sh = New-Object -comObject Shell.Application
                $items = $sh.namespace(17).Items()
                ForEach($item in $items)
				{
					If($item.type -eq "USB Drive")
					{
                        $driveLetter = $item.Name
						Write-Output "Removable Storage detected"
						Write-Output "Drive name is $driveLetter"
                        Write-Output "Invoking Eject..."
                        $item.InvokeVerb("Eject")
                        Write-Output "Ejected successfully"
					}
				}
        }
        catch [System.Exception]{
                Write-Output "An error occurred while attempting to unmount USB removable storage. Error message: $($_.Exception.Message)"
        }
}

<# Section - Function to monitor the progress of SYSTEM Drive Decryption operation #>
Function MonitorSysVolDecryption()
{
   # Monitor Decryption State of OS Volume
   $SysVol = ""
   $SysVol = $env:SystemDrive
   Try
   {
        $BitLockerSysVolDecryptStatus = Get-BitLockerVolume -MountPoint $SysVol -ErrorAction Stop
   }
   catch [System.Exception] {
                Write-Output "Failed to retrieve Bitlocker status of System drive. Error message: $($_.Exception.Message)"
   }
   if ($BitLockerSysVolDecryptStatus -ne $null)
   {
       if ($BitLockerSysVolDecryptStatus.VolumeStatus -like "DecryptionInProgress") 
       {
           do {
                $BitLockerSysVolDecryptStatus = Get-BitLockerVolume -MountPoint $SysVol -ErrorAction Stop
                Write-Output "Current encryption percentage: $($BitLockerSysVolDecryptStatus.EncryptionPercentage)"
                Start-Sleep -Seconds 60
           }until ($BitLockerSysVolDecryptStatus.EncryptionPercentage -eq 0)
           Write-Output "Decryption of OS drive $SysVol has completed!"
       }
   }
}

<# Section - Function to check for presence of Fixed Drive for the purpose of SYSTEM Drive Decryption #>
Function CheckForFixedDrivePresence()
{
  # Detecting presence of Fixed Drive for processing
  Try 
    {
    $Drives = (Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType = 3").DeviceID
    }
  catch [System.Exception] {
      Write-Output "Error message: $($_.Exception.Message)"
  }

  Try
    {
    $USBDrives = gwmi win32_diskdrive | ?{$_.interfacetype -eq "USB"} | %{gwmi -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID=`"$($_.DeviceID.replace('\','\\'))`"} WHERE AssocClass = Win32_DiskDriveToDiskPartition"} |  %{gwmi -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID=`"$($_.DeviceID)`"} WHERE AssocClass = Win32_LogicalDiskToPartition"} | %{$_.deviceid}
    }
  catch [System.Exception] {
      Write-Output "Error message: $($_.Exception.Message)"
  }

  Try
    {
    $ExtDrives = gwmi win32_diskdrive | ?{$_.mediatype -eq "External hard disk media"} | %{gwmi -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID=`"$($_.DeviceID.replace('\','\\'))`"} WHERE AssocClass = Win32_DiskDriveToDiskPartition"} |  %{gwmi -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID=`"$($_.DeviceID)`"} WHERE AssocClass = Win32_LogicalDiskToPartition"} | %{$_.deviceid}
    }
  catch [System.Exception] {
      Write-Output "Error message: $($_.Exception.Message)"
  }

  Write-Output "Processing Drives $($Drives)"

  # Loop through all Local Drives
  ForEach ($Drive in $Drives)
            {
                if ($Drive -ne $env:SystemDrive)
                    {
                                        if(($USBDrives -contains $Drive) -or ($ExtDrives -contains $Drive))
                                            {
                                                Write-Output "Ignoring $($Drive) as it is detected as removable drive"
                                            }
                                        else
                                            {
                                                Write-Output "$($Drive) is Fixed drive"
                                                Write-Output "Need to check if $($Drive) is Bitlocker Encrypted"
                                                
                                                Try
                                                    {
                                                        $BitlockerStatusCheckForFD = Get-BitlockerVolume -MountPoint $Drive -ErrorAction Stop
                                                    }
                                                catch [System.Exception] {
                                                                    Write-Output "Failed to check for Bitlocker status on drive $Drive. Error message: $($_.Exception.Message)"
                                                          }
                                                
                                                if ($BitlockerStatusCheckForFD -ne $null)
                                                   {
                                                     Write-Output "Detected Fixed Drive $($Drive) is Bitlokcer Protected!"
                                                     if ($BitlockerStatusCheckForFD.KeyProtector.Count -eq 3)
                                                     {
                                                         Write-Output "Auto-Unlock keys maybe present"
                                                         Write-Output "Proceeding to clear auto-unlock keys and disable Bitlocker on System drive $env:SystemDrive"
                                                         Try
                                                             {
                                                                Clear-BitLockerAutoUnlock
                                                                Disable-Bitlocker -MountPoint $env:SystemDrive
                                                                Write-Output "Bitlocker is now disabled on System drive $env:SystemDrive"
                                                             }
                                                          catch [System.Exception] {
                                                                        Write-Output "Failed to disable Bitlocker on System drive $env:SystemDrive. Error message: $($_.Exception.Message)"
                                                              }
                                                          # Function call to monitor the SysVol decryption progress
                                                          MonitorSysVolDecryption
                                                          Start-Sleep 5
                                                          # Function call to prepare for Re-encryption of SysVol
                                                          DetectRemediateTPMOwnership
                                                          Start-Sleep 5
                                                          DetectRemediateRemovableMedia
                                                          Start-Sleep 5
                                                          # Function call to Re-encrypt SysVol
                                                          ReEncryptSystemDriveFEXtsAes256
                                                     }
                                                     else
                                                     {
                                                          Write-Output "Detected Fixed Drive $($Drive) is not Bitlokcer Protected!"
                                                          Write-Output "Proceeding to disable Bitlocker on System drive $env:SystemDrive"
                                                          Try
                                                              {
                                                                 Disable-Bitlocker -MountPoint $env:SystemDrive
                                                                 Write-Output "Bitlocker is now disabled on System drive $env:SystemDrive"
                                                              }
                                                              catch [System.Exception] {
                                                                           Write-Output "Failed to disable Bitlocker on System drive $env:SystemDrive. Error message: $($_.Exception.Message)"
                                                              }
                                                          # Function call to monitor the SysVol decryption progress
                                                          MonitorSysVolDecryption
                                                          Start-Sleep 5
                                                          # Function call to prepare for Re-encryption of SysVol
                                                          DetectRemediateTPMOwnership
                                                          Start-Sleep 5
                                                          DetectRemediateRemovableMedia
                                                          Start-Sleep 5
                                                          # Function call to Re-encrypt SysVol
                                                          ReEncryptSystemDriveFEXtsAes256
                                                     }
                                                   }
                                            }
                                      }
                else
                    {
                                           Write-Output "$($Drive) is not a Fixed drive"
                                           Write-Output "No Fixed Drive detected!"
                                           Write-Output "Proceeding to disable Bitlokcer on System drive $env:SystemDrive"
                                    Try{
                                           Disable-Bitlocker -MountPoint $env:SystemDrive
                                           Write-Output "Bitlocker is now disabled on System drive $env:SystemDrive"
                                       }
                                       catch [System.Exception] {
                                           Write-Output "Failed to disable Bitlocker on System drive $env:SystemDrive. Error message: $($_.Exception.Message)"
                                       }
                                    # Function call to monitor the SysVol decryption progress
                                    MonitorSysVolDecryption
                                    Start-Sleep 5
                                    # Function call to prepare for Re-encryption of SysVol
                                    DetectRemediateTPMOwnership
                                    Start-Sleep 5
                                    DetectRemediateRemovableMedia
                                    Start-Sleep 5
                                    # Function call to Re-encrypt SysVol
                                    ReEncryptSystemDriveFEXtsAes256
                    }
            }
}

<# Section - Function for SYSTEM Drive Decryption #>
# Function call will trigger decryption of OS Volume only if existing Encryption state Is Not Full Encryption and Encryption method Is Not XtsAes256
Function DecryptSystemDriveIfNotFEXtsAes256()
{
    # Declaring Bitlocker OS Drive Mount Point
    $SysVol = $env:SystemDrive

    # Get current Bitlocker OS volume status to check if it is fully encrypted with 256-bit encryption, else proceed for decryption rightaway 
    try
        {
            $BitlockerSysVolStatus = Get-BitLockerVolume -MountPoint $SysVol -ErrorAction Stop
        }
    catch [System.Exception] {
            Write-Output "Failed to retrieve Bitlocker status of System drive. Error message: $($_.Exception.Message)"
        }

    if ($BitlockerSysVolStatus -ne $null)
    {
       # When OS Volume is already Fully Encrypted with XtsAes256 bit encryption...
       if (($BitlockerSysVolStatus.EncryptionMethod -eq "XtsAes256") -and ($BitlockerSysVolStatus.VolumeStatus -like "FullyEncrypted"))
            {
                Write-Output "System drive $SysVol is already Fully Encrypted with XtsAes256 bit encryption."
                Write-Output "Need to check the presence and status for Key protectors"
                if (($BitLockerSysVolStatus.ProtectionStatus -eq 'On') -and ($BitLockerSysVolStatus.KeyProtector.KeyProtectorType -contains 'Tpm') -and ($BitLockerSysVolStatus.KeyProtector.KeyProtectorType -contains 'RecoveryPassword'))
                    {
                        Write-Output "Bitlocker is already enabled on System drive $SysVol with TPM and Recovery Password as key protectors"
                        Write-Output "System drive $SysVol has Bitlokcer protection status ON"
                        Write-Output "Decryption action not needed on System drive $SysVol"
                        Write-Output "Proceed to backup recovery key of System drive $SysVol to AAD, just in case..."
                        
                        # Function call to backup recovery key to AAD just in case
                        BackupSysVolRecoveryKeyToAAD
                    }
                else
                    {
                        Write-Output "System drive $SysVol is Fully Encrypted with XtsAes256 bit encryption, but proper key protectors are not detected!"
                        Write-Output "Proceeding to disable Bitlocker for System drive $SysVol"
                        Write-Output "Need to check for presence of Auto-Unlock key, if any..."
                        Write-Output "Making function call to check for the presence of fixed drive, if any and its bitlocker status..."

                        # Function call to check for presence of Fixed Drive for the purpose of SYSTEM Drive Decryption
                        CheckForFixedDrivePresence    
                    }
            }

       # When OS Volume is in Fully Decrypted state but key protectors are found...
       elseif (($BitlockerSysVolStatus.VolumeStatus -like "FullyDecrypted") -and ($BitLockerSysVolStatus.KeyProtector.Count -ne 0))
            {
                Write-Output "System drive $SysVol is currently in Fully Decrypted state but presence of key protectors detected."
                Write-Output "Proceeding to disable Bitlokcer for System drive $SysVol"
                Write-Output "Need to check for presence of Auto-Unlock key"
                Write-Output "Making function call to check for the presence of Fixed drive(s), if any and its bitlocker status..."

                # Function call to check for presence of Fixed Drive for the purpose of SYSTEM Drive Decryption
                CheckForFixedDrivePresence   
            }
       # When OS Volume is in Fully Decrypted state...
       elseif (($BitlockerSysVolStatus.VolumeStatus -like "FullyDecrypted") -and ($BitlockerSysVolStatus.KeyProtector.Count -eq 0))
            {
                Write-Output "System drive $SysVol is in Fully Decrypted state."
                Write-Output "Decryption action not needed on System drive $SysVol"
            }
       # When OS Volume is in any other state which is not the desired configuration...
       else
            {
                Write-Output "System drive $SysVol is either not in Fully Encrypted state and/or not encrypted with XtsAes256 key strength."
                Write-Output "Proceeding to decrypt System drive $SysVol"
                Write-Output "Need to check for presence of Auto-Unlock key"
                Write-Output "Making function call to check for the presence of Fixed drive(s), if any and its bitlocker status..."

                # Function call to check for presence of Fixed Drive for the purpose of SYSTEM Drive Decryption
                CheckForFixedDrivePresence    
            }
    }
}

<# Section - Function to monitor the progress of SYSTEM Drive Encryption operation #>
Function MonitorSysVolEncryption()
{
        # Monitor Encryption State of OS Volume
        
        $SysVol = ""
        $SysVol = $env:SystemDrive
        Try
        {
          $BitLockerSysVolEncryptStatus = Get-BitLockerVolume -MountPoint $SysVol -ErrorAction Stop
        }
        catch [System.Exception] {
          Write-Output "Failed to retrieve Bitlocker status of System drive. Error message: $($_.Exception.Message)"
        }
        if ($BitLockerSysVolEncryptStatus -ne $null)
        {
            if ($BitLockerSysVolEncryptStatus.VolumeStatus -like "EncryptionInProgress") 
            {
                do {
                        $BitLockerSysVolEncryptStatus = Get-BitLockerVolume -MountPoint $SysVol
                        Write-Output "Current encryption percentage progress: $($BitLockerSysVolEncryptStatus.EncryptionPercentage)"
                        Start-Sleep -Seconds 60
                }until ($BitLockerSysVolEncryptStatus.EncryptionPercentage -eq 100)
                Write-Output "Encryption of OS drive $SysVol has now completed"
            }
        }
}

<# Section - Function to backup SYSTEM Drive Recovery Key to AAD #>
Function BackupSysVolRecoveryKeyToAAD()
{
        $OSVol = $env:Systemdrive
         Try
        {
          $BitLockerOSVolStatus = Get-BitLockerVolume -MountPoint $OSVol -ErrorAction Stop
        }
        catch [System.Exception] {
          Write-Output "Failed to retrieve Bitlocker status of System drive. Error message: $($_.Exception.Message)"
        }

        if ($BitLockerOSVolStatus -ne $null)
        {
            Write-Output "Preparing to upload System Volume $OSVol recovery key to AAD"
            if(($BitLockerOSVolStatus.VolumeStatus -like "FullyEncrypted") -and ($BitLockerOSVolStatus.KeyProtector.Count -eq 2))
            {
                try 
                {
                     # Attempt to backup recovery password to Azure AD device object
                     Write-Output "Attempting to backup recovery password to Azure AD"
                     $RecoveryPasswordKeyProtector = $BitLockerOSVolStatus.KeyProtector | Where-Object { $_.KeyProtectorType -like "RecoveryPassword" }
                        if ($RecoveryPasswordKeyProtector -ne $null) 
                        {
                             BackupToAAD-BitLockerKeyProtector -MountPoint $OSVol -KeyProtectorId $RecoveryPasswordKeyProtector.KeyProtectorId
                             Write-Output "Successfully backed up recovery password to AAD"
                        }
                        else
                        {
                             Write-Output "Unable to determine proper recovery password key protector to back up"
                        }
                }
                catch [System.Exception] {
                      Write-Output "An error occurred while attempting to backup recovery password for SysVol $OSVol to Azure AD. Error message: $($_.Exception.Message)"
                }
            }
        }
}

<# Section - Function for SYSTEM Drive Re-Encryption #>
<# Function call works for only TPM-enabled devices. Enables Bitlocker encryption of OS Volume with Encryption state Full Encryption and Encryption method XtsAes256 #>
Function ReEncryptSystemDriveFEXtsAes256()
{

        Write-Output "Proceeding to re-encrypt OS drive"

        # Declaring Bitlocker OS Drive Mount Point
        $OSDrive = $env:SystemDrive

        # Get current Bitlocker OS volume status
        try
            {
                $BitlockerSysVolDriveStatus = Get-BitLockerVolume -MountPoint $OSDrive -ErrorAction Stop
            }
        catch [System.Exception] {
                Write-Output "Failed to retrieve Bitlocker status of System drive. Error message: $($_.Exception.Message)"
        }
        
        if ($BitlockerSysVolDriveStatus -ne $null)
        {
            if(($BitlockerSysVolDriveStatus.VolumeStatus -like "FullyDecrypted") -and ($BitlockerSysVolDriveStatus.KeyProtector.Count -eq 0))
            {
                # Enable BitLocker with TPM key protector
                try 
                {
                        Write-Output "Trying to enable BitLocker protection with TPM key protector for OS Volume: $($OSDrive)"
                        Enable-BitLocker -MountPoint $OSDrive -EncryptionMethod XtsAes256 -TpmProtector -SkipHardwareTest -ErrorAction Stop
                }
                catch [System.Exception] {
                        Write-Output "An error occurred while enabling BitLocker with TPM key protector for mount point '$($OSDrive)'. Error message: $($_.Exception.Message)"
                        Disable-Bitlocker -MountPoint $OSDrive
                        Write-Output "Bitlokcer state for OS Drive $OSDrive reverted!"
                }

                # Enable BitLocker with recovery password key protector
                try 
                {
                        Write-Output "Trying to enable BitLocker protection with recovery password key protector for mount point: $($OSDrive)"
                        Enable-BitLocker -MountPoint $OSDrive -EncryptionMethod XtsAes256 -RecoveryPasswordProtector -SkipHardwareTest -ErrorAction Stop
                }
                catch [System.Exception] {
                        Write-Output "An error occurred while enabling BitLocker with recovery password key protector for mount point '$($OSDrive)'. Error message: $($_.Exception.Message)"
                        Disable-Bitlocker -MountPoint $OSDrive
                        Write-Output "Bitlokcer state for OS Drive $OSDrive reverted!"
                }

                # Function call to monitor progress of Encryption operation
                MonitorSysVolEncryption
                Start-Sleep 10
                # Function call to backup recovery keys to AAD
                BackupSysVolRecoveryKeyToAAD
            }
            else 
            {
                  # BitLocker is in wait state
                  Invoke-Executable -FilePath "C:\windows\system32\manage-bde.exe" -Arguments "-On $($OSDrive)"
            }       
        }
        else
        {
            Write-Output "Current encryption status of the OS drive is detected as: $($BitlockerSysVolDriveStatus.VolumeStatus)"
        }
}

<# Section - Function for Fixed Drives #>
Function ProcessFixedDriveIfNotXtsAes256($sDrive)
{ 
    # Section Decryption
    Write-Output "Proceeding to decrypt Fixed drive $sDrive"
    try
    {
       Disable-Bitlocker -MountPoint $sDrive
       Write-Output "Decryption in Progress..."
    }
    catch [System.Exception] {
                Write-Output "Failed to decrypt Fixed drive $sDrive. Error message: $($_.Exception.Message)"
    }

    # Monitor Decryption State
    $bitLockerStatus = Get-BitLockerVolume -MountPoint $sDrive -ErrorAction Stop
    if ($bitLockerStatus.VolumeStatus -like "DecryptionInProgress") 
       {
          do {
                $bitLockerStatus = Get-BitLockerVolume -MountPoint $sDrive -ErrorAction Stop
                Write-Output "Current encryption percentage: $($bitLockerStatus.EncryptionPercentage)"
                Start-Sleep -Seconds 60
             }
          until ($bitLockerStatus.EncryptionPercentage -eq 0)
          Write-Output "Decryption of Fixed drive $sDrive has completed!"
       }
    
    # Section Encryption
    Write-Output "Proceeding to re-encrypt Fixed drive $sDrive"
    $bitLockerStatus = Get-BitLockerVolume -MountPoint $sDrive -ErrorAction Stop
    if ($bitLockerStatus.VolumeStatus -eq "FullyDecrypted")
    {
        # Enable Bitlocker using RecoveryKey stored on C:\
        try
            {
                Enable-BitLocker -MountPoint $sDrive -EncryptionMethod XtsAes256 -RecoveryKeyProtector -RecoveryKeyPath $env:SystemDrive -ErrorAction Stop -SkipHardwareTest -Confirm:$False
                Write-Output "Bitlocker enabled for $sDrive using RecoveryKeyProtector"
            }
        catch [System.Exception] {
                Write-Output "Failed to enable Bitlocker for $sDrive using RecoveryKeyProtector. Error message: $($_.Exception.Message)"
        }

        #Enable Bitlocker with a normal password protector
        try
            {
                Enable-BitLocker -MountPoint $sDrive -EncryptionMethod XtsAes256 -RecoveryPasswordProtector -ErrorAction Stop -SkipHardwareTest -Confirm:$False
                Write-Output "Bitlocker recovery password set for $sDrive"
            }
        catch [System.Exception] {
                Write-Output "Failed to enable Bitlocker for $sDrive using RecoveryPasswordProtector. Error message: $($_.Exception.Message)"
        }
        
        # Enable AutoUnlock
        try
            {
                Enable-BitLockerAutoUnlock -MountPoint $sDrive
                Write-Output "Bitlocker AutoUnlock enabled for $sDrive"
            }
        catch [System.Exception] {
                Write-Output "Failed to enable Bitlocker AutoUnlock for $sDrive. Error message: $($_.Exception.Message)"
                Write-Output "Bitlocker will be disabled for $sDrive"
                Disable-Bitlocker -MountPoint $sDrive
        }
    }

    # Section - Upload Recovery Key to AAD
    Write-Output "Proceed to upload recovery key to AAD for $sDrive"
    $BitLockerFDrive = Get-BitLockerVolume -MountPoint $sDrive -ErrorAction Stop  
    # Attempt to backup recovery password to Azure AD device object
    Write-Output "Attempting to backup recovery password for $sDrive to Azure AD"
    $FDRecoveryPasswordKeyProtector = $BitLockerFDrive.KeyProtector | Where-Object {$_.KeyProtectorType -eq "RecoveryPassword" }
    if ($FDRecoveryPasswordKeyProtector -ne $null)
    {
        try 
            {        
                BackupToAAD-BitLockerKeyProtector -MountPoint $BitLockerFDrive.MountPoint -KeyProtectorId $FDRecoveryPasswordKeyProtector.KeyProtectorId
                Write-Output "Successfully backed up recovery password to AAD"
            }
        catch [System.Exception] {
                Write-Output "An error occurred while attempting to backup recovery password to Azure AD. Error message: $($_.Exception.Message)"
                Disable-Bitlocker -MountPoint $sDrive
                Write-Output "Bitlocker state of Fixed Drive $sDrive is being reverted"
        }
    }
    else
        {
          Write-Output "Unable to determine proper recovery password key protector to back up"
          Disable-Bitlocker -MountPoint $sDrive
          Write-Output "Bitlocker state of Fixed Drive $sDrive is being reverted"
        }
}


<#-----------------------------------------------------------------------------------------------------------------------------------#>
<#------------------------------------------MAIN SCRIPT STARTS FROM HERE-------------------------------------------------------#>
<#-----------------------------------------------------------------------------------------------------------------------------------#>


# Script Execution Log

$PackageName = "Bitlocker"
$Log_Filename = "$PackageName.log"
$Path_local = "C:\Temp"
$TestPath = "$Path_local\$Log_Filename"
If(!(Test-Path $TestPath))
    {
        New-Item -Path $Path_Local -Name $Log_FileName -ItemType "File" -Force
    }
Start-Transcript -Path "$TestPath" -Force

# Import Bitlocker module into current PS session

Try 
    {
        Import-Module -Name "BitLocker" -DisableNameChecking -Verbose:$false -ErrorAction Stop
        Write-Output "Bitlocker module loaded to current PS session"
    }
catch [System.Exception] 
    {
        Write-Output "An error occurred while trying to load Bitlokcer module. Error message: $($_.Exception.Message)"
    }

# Validate TPM state

$TPMStatusInfo = Get-WmiObject -Class Win32_TPM -EnableAllPrivileges -Namespace "root\CIMV2\Security\MicrosoftTpm"

<# If section contains bitlocker encryption code to be executed only on TPM-enabled devices #>
<# Else section contains bitlocker encryption code to be executed on non-TPM devices [In future version] #>

if ($TPMStatusInfo.IsEnabled_InitialValue -eq $True -and $TPMStatusInfo.IsActivated_InitialValue -eq $True)
    {
        Write-Output "TPM is Enabled and Activated"
        Write-Output "Script will proceed to trigger actions..."
        try 
        {
                # Function call to decrypt OS Volume if it does not pass the required parameters - XtsAes256 bit Full Encryption
                DecryptSystemDriveIfNotFEXtsAes256
                
                # Check for Fixed Drive
                $Drives = (Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType = 3").DeviceID
                $USBDrives = gwmi win32_diskdrive | ?{$_.interfacetype -eq "USB"} | %{gwmi -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID=`"$($_.DeviceID.replace('\','\\'))`"} WHERE AssocClass = Win32_DiskDriveToDiskPartition"} |  %{gwmi -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID=`"$($_.DeviceID)`"} WHERE AssocClass = Win32_LogicalDiskToPartition"} | %{$_.deviceid}
                $ExtDrives = gwmi win32_diskdrive | ?{$_.mediatype -eq "External hard disk media"} | %{gwmi -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID=`"$($_.DeviceID.replace('\','\\'))`"} WHERE AssocClass = Win32_DiskDriveToDiskPartition"} |  %{gwmi -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID=`"$($_.DeviceID)`"} WHERE AssocClass = Win32_LogicalDiskToPartition"} | %{$_.deviceid}

                Write-Output "Processing Drives $($Drives)"

                # Loop through all Local Drives
                ForEach ($Drive in $Drives)
                {
                    # Do not process $env:SystemDrive
                    If ($Drive -ne $env:SystemDrive)
                    {
                        # Do not process any USB connected devices (Should be Bitlocker To Go)
                        if (($USBDrives -contains $Drive) -or ($ExtDrives -contains $Drive))
                        {
                            Write-Output "Ignoring $($Drive) as it is Removable"
                        }
                        else
                        { 
                           Write-Output "Processing $($Drive)"
                           ProcessFixedDriveIfNotXtsAes256($Drive)
                        }
                    }
                    else
                    {
                        Write-Output "Ignoring $($Drive) as it is System Drive"
                    }
                }
        }
        catch [System.Exception] {
            Write-Output "An error occurred while trying to check TPM state. Error message: $($_.Exception.Message)"
        }
    }
else 
    {
            Write-Output "TPM not Enabled and Activated - Need to use without TPM solution"
    }