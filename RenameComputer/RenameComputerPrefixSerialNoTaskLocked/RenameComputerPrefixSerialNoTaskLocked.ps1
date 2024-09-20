<# 
.DESCRIPTION 
This script is designed to rename a computer based on its asset tag or BIOS serial number.
It checks for domain join status, connectivity, and whether it's running in the Enrollment Status Page / Autopilot provisioning before proceeding with the rename operation.
#> 

Param()

# Set up logging to keep track of script execution and any potential issues.
$dest = "$($env:ProgramData)\Microsoft\RenameComputer"
if (-not (Test-Path $dest)) {
    mkdir $dest
}
Start-Transcript "$dest\RenameComputer.log" -Append

# Function for consistent logging
function Write-Log {
    param([string]$Message)
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Write-Host $logMessage
}

Write-Log "Script execution started"

# This section ensures the script runs in 64-bit mode on 64-bit systems.
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64") {
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe") {
        Write-Log "Relaunching script in 64-bit PowerShell"
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy bypass -File "$PSCommandPath" -Prefix $Prefix
        Exit $lastexitcode
    }
}

# Get computer info with error handling
try {
    $details = Get-ComputerInfo
    Write-Log "Successfully retrieved computer information"
}
catch {
    Write-Log "Error retrieving computer information: $_"
    Stop-Transcript
    Exit 1
}

# Check if script is running inside the Enrollment Status Page / Autopilot provisioning
if ($details.CsUserName -match "defaultUser") {
    Write-Log "Script is running in the Enrollment Status Page / Autopilot provisioning"
    
    # Check if the computer is domain-joined.
    $goodToGo = $true
    if (-not $details.CsPartOfDomain) {
        Write-Log "This computer is not part of a domain. Renaming cannot proceed."
        $goodToGo = $false
        Stop-Transcript
        Exit 1
    }

    # Verify connectivity to the domain.
    try {
        $dcInfo = [ADSI]"LDAP://RootDSE"
        if ($null -eq $dcInfo.dnsHostName) {
            Write-Log "Unable to establish connectivity to the domain. Please check network settings."
            $goodToGo = $false
        }
    }
    catch {
        Write-Log "Error checking domain connectivity: $_"
        $goodToGo = $false
        Stop-Transcript
        Exit 1
    }

    # Main renaming logic
    if ($goodToGo) {
        try {
            $systemEnclosure = Get-CimInstance -ClassName Win32_SystemEnclosure
            Write-Log "Retrieved system enclosure information"

            # Determine the asset tag or use BIOS serial number as a fallback
            if (($null -eq $systemEnclosure.SMBIOSAssetTag) -or ($systemEnclosure.SMBIOSAssetTag -eq "")) {
                $assetTag = $details.BiosSerialNumber ?? "UnknownSerial"
                Write-Log "Using BIOS Serial Number as asset tag: $assetTag"
            }
            else {
                $assetTag = $systemEnclosure.SMBIOSAssetTag
                Write-Log "Using SMBIOSAssetTag as asset tag: $assetTag"
            }

            $currentComputerName = $env:ComputerName
            $tempComputerName = $currentComputerName.Split('-')
            $assetTag = $assetTag.Replace("-", "")

            # Ensure the asset tag portion of the new name doesn't exceed 12 characters
            if ($assetTag.Length -gt 12) {
                $serial = $assetTag.Substring(0, 10)
            }
            else {
                $serial = $assetTag
            }

            # Construct the new computer name
            $temp = $tempComputerName[0]
            $newName = "$temp-$serial"
            Write-Log "Constructed new computer name: $newName"

            # Perform the actual rename operation
            Write-Log "Initiating computer rename to: $newName"
            Rename-Computer -NewName $newName -Force -ErrorAction Stop
            Write-Log "Computer successfully renamed to: $newName"

            # Create a tag file to indicate that this script has successfully run.
            if (-not (Test-Path "$($env:ProgramData)\Microsoft\RenameComputer")) {
                Mkdir "$($env:ProgramData)\Microsoft\RenameComputer"
            }
            Set-Content -Path "$($env:ProgramData)\Microsoft\RenameComputer\RenameComputer.ps1.tag" -Value "Installed"
            Write-Log "Created tag file to indicate successful script execution"

            Write-Log "Computer rename completed during ESP/OOBE phase. Exiting with code 1641 to initiate immediate reboot."
            Stop-Transcript
            Exit 1641
        }
        catch {
            Write-Log "Error during rename process: $_"
            Stop-Transcript
            Exit 1
        }
    }
} 
elseif ($details.CsUserName -notmatch "defaultUser") {
    Write-Log "Script is running outside the Enrollment Status Page / Autopilot provisioning. Exiting script."
    Stop-Transcript
    Exit 1
}
else {
    Write-Log "Unable to proceed with computer rename due to unmet prerequisites. Please check domain join status and network connectivity."
    Stop-Transcript
    Exit 1
}