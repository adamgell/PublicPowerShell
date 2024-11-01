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
if ("$env:PROCESSOR_ARCHITECTURE" -ne "AMD64") {
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
            Stop-Transcript
            Exit 1
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
            # Get Win32_SystemEnclosure with error handling
            try {
                $systemEnclosure = Get-CimInstance -ClassName Win32_SystemEnclosure
                Write-Log "Successfully retrieved Win32_SystemEnclosure information"
            }
            catch {
                Write-Log "Error retrieving Win32_SystemEnclosure information: $_"
                Stop-Transcript
                Exit 1
            }
            
            # Determine the asset tag or use BIOS serial number as a fallback
            if (($null -eq $systemEnclosure.SMBIOSAssetTag) -or ($systemEnclosure.SMBIOSAssetTag -eq "")) {
                $assetTag = $details.BiosSerialNumber
                Write-Log "Using BIOS Serial Number as asset tag: $assetTag"
            }
            else {
                $assetTag = $systemEnclosure.SMBIOSAssetTag
                Write-Log "Using SMBIOSAssetTag as asset tag: $assetTag"
            }

            # Uncomment this line to set a predefined asset tag if needed for testing purposes
            # $assetTag = "PF4J0KCG"

            $currentComputerName = $env:ComputerName
            # Uncomment this line to set a predefined computername if needed for testing purposes
            # $currentComputerName = "BFSSC-34128097234890423"

            Write-Log "Current Computer Name: $currentComputerName"

            $tempComputerName = $currentComputerName.Split('-')
            $prefix = $tempComputerName[0]
            Write-Log "Prefix: $prefix"

            $assetTag = $assetTag.Replace("-", "").Replace(" ", "")
            Write-Log "Cleaned Asset Tag: $assetTag"

            # Determine the system type and construct the new name
            if ($details.CsPCSystemTypeEx -eq "Desktop") {
                $newName = "$prefix" + "D" + "$assetTag"
                Write-Log "Desktop system detected. Using naming format: PREFIX + D + ASSET TAG"
            }
            else {
                $newName = "$prefix" + "$assetTag"
                Write-Log "Non-desktop system detected. Using naming format: PREFIX + ASSET TAG"
            }

            # Ensure the new name doesn't exceed 15 characters
            if ($newName.Length -gt 15) {
                $newName = $newName.Substring(0, 15)
                Write-Log "New name exceeded 15 characters. Truncated to: $newName"
            }

            Write-Log "Constructed new computer name: $newName"

            # Perform the actual rename operation
            Write-Log "Initiating computer rename to: $newName"
            Rename-Computer -NewName $newName -Force -ErrorAction Continue
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