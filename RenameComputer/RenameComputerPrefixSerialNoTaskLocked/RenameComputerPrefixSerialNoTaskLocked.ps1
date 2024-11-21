# Computer Rename Script
# Purpose: Renames computers during Autopilot/ESP phase based on asset tag or serial number
# Usage: Run with -WhatIf switch to simulate changes without applying them

[CmdletBinding()]
Param(
    [Parameter()]
    [switch]$WhatIf  # Simulation mode switch
)

#region Setup and Logging
# Initialize logging directory
$dest = "$($env:ProgramData)\Microsoft\RenameComputer"
if (-not (Test-Path $dest)) {
    mkdir $dest
}
Start-Transcript "$dest\RenameComputer.log" -Append

function Write-Log {
    param([string]$Message)
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Write-Host $logMessage
}

Write-Log "Script execution started"
#endregion

#region Validation Checks
# Get computer information
try {
    $details = Get-ComputerInfo
    Write-Log "Successfully retrieved computer information"
}
catch {
    Write-Log "Error retrieving computer information: $_"
    Stop-Transcript
    Exit 1
}

# Check execution context and domain status
if (-not $WhatIf) {
    # Verify running in ESP/Autopilot context
    if ($details.CsUserName -notmatch "defaultUser") {
        Write-Log "Script is running outside the Enrollment Status Page / Autopilot provisioning. Exiting script."
        Stop-Transcript
        Exit 1
    }

    # Verify domain join status
    if (-not $details.CsPartOfDomain) {
        Write-Log "This computer is not part of a domain. Renaming cannot proceed."
        Stop-Transcript
        Exit 1
    }

    # Verify domain connectivity
    try {
        $dcInfo = [ADSI]"LDAP://RootDSE"
        if ($null -eq $dcInfo.dnsHostName) {
            Write-Log "Unable to establish connectivity to the domain. Please check network settings."
            Stop-Transcript
            Exit 1
        }
    }
    catch {
        Write-Log "Error checking domain connectivity: $_"
        Stop-Transcript
        Exit 1
    }
}
#endregion

#region Asset Tag Determination
# Get system enclosure information
try {
    $systemEnclosure = Get-CimInstance -ClassName Win32_SystemEnclosure
    Write-Log "Successfully retrieved Win32_SystemEnclosure information"
}
catch {
    Write-Log "Error retrieving Win32_SystemEnclosure information: $_"
    Stop-Transcript
    Exit 1
}

Write-Log "BIOS Serial Number from ComputerInfo: [$($details.BiosSeralNumber)]"
Write-Log "Asset Tag from SystemEnclosure: [$($systemEnclosure.SMBIOSAssetTag)]"

# Determine asset tag using fallback logic
$assetTag = if (($null -eq $systemEnclosure.SMBIOSAssetTag) -or 
               ($systemEnclosure.SMBIOSAssetTag -eq "") -or 
               ($systemEnclosure.SMBIOSAssetTag -eq "No Asset Tag")) {
    if ([string]::IsNullOrWhiteSpace($details.BiosSeralNumber)) {
        "NOSERIALNUM"
    }
    else {
        $details.BiosSeralNumber
    }
}
else {
    $systemEnclosure.SMBIOSAssetTag
}
Write-Log "Selected asset tag: [$assetTag]"
#endregion

#region Name Construction
$currentComputerName = $env:ComputerName
Write-Log "Current Computer Name: $currentComputerName"

# Extract prefix from current name (portion before hyphen)
$prefix = if ($currentComputerName -like "*-*") {
    $currentComputerName.Split('-')[0]
}
else {
    $currentComputerName
}
Write-Log "Prefix: $prefix"

# Clean asset tag
$assetTag = if ([string]::IsNullOrWhiteSpace($assetTag)) {
    "NOASSET"
}
else {
    $assetTag.Replace("-", "").Replace(" ", "")
}
Write-Log "Cleaned Asset Tag: $assetTag"

# Construct new name with desktop designation if applicable
$newName = if ($details.CsPCSystemTypeEx -eq "Desktop") {
    "$prefix" + "D" + "$assetTag"
}
else {
    "$prefix" + "$assetTag"
}

# Truncate if necessary
if ($newName.Length -gt 15) {
    $newName = $newName.Substring(0, 15)
    Write-Log "New name exceeded 15 characters. Truncated to: $newName"
}

Write-Log "Constructed new computer name: $newName"
#endregion

#region Rename and Cleanup
if ($WhatIf) {
    Write-Log "WhatIf: Would rename computer from $currentComputerName to $newName and restart"
    Stop-Transcript
    Exit 0
}

# Perform rename
Write-Log "Initiating computer rename to: $newName"
Rename-Computer -NewName $newName -Force -ErrorAction Continue -Restart
Write-Log "Computer successfully renamed to: $newName"

# Create completion tag
if (-not (Test-Path "$($env:ProgramData)\Microsoft\RenameComputer")) {
    Mkdir "$($env:ProgramData)\Microsoft\RenameComputer"
}
Set-Content -Path "$($env:ProgramData)\Microsoft\RenameComputer\RenameComputer.ps1.tag" -Value "Installed"
Write-Log "Created tag file to indicate successful script execution"

Write-Log "Computer rename completed during ESP/OOBE phase. Exiting with code 1641 to initiate immediate reboot."
Stop-Transcript
Exit 1641
#endregion