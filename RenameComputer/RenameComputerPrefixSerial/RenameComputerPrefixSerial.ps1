<# 

.DESCRIPTION 
 Rename the computer 

#> 

Param()

# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITECTURE" -ne "AMD64")
{
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe")
    {
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy bypass -File "$PSCommandPath" -Prefix $Prefix
        Exit $lastexitcode
    }
}

# Create a tag file just so Intune knows this was installed
if (-not (Test-Path "$($env:ProgramData)\Microsoft\RenameComputer")) {
    Mkdir "$($env:ProgramData)\Microsoft\RenameComputer"
}
Set-Content -Path "$($env:ProgramData)\Microsoft\RenameComputer\RenameComputer.ps1.tag" -Value "Installed"

# Initialization
$dest = "$($env:ProgramData)\Microsoft\RenameComputer"
if (-not (Test-Path $dest)) {
    mkdir $dest
}
Start-Transcript "$dest\RenameC# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64")
{
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe")
    {
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy bypass -File "$PSCommandPath" -Prefix $Prefix
        Exit $lastexitcode
    }
}omputer.log" -Append

# Make sure we are already domain-joined
$goodToGo = $true
$details = Get-ComputerInfo
if (-not $details.CsPartOfDomain) {
    Write-Host "Not part of a domain."
    $goodToGo = $false
}

# Make sure we have connectivity
$dcInfo = [ADSI]"LDAP://RootDSE"
if ($null -eq $dcInfo.dnsHostName) {
    Write-Host "No connectivity to the domain."
    $goodToGo = $false
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
else {
    # Check to see if already scheduled
    $existingTask = Get-ScheduledTask -TaskName "RenameComputer" -ErrorAction SilentlyContinue
    if ($null -ne $existingTask) {
        Write-Host "Scheduled task already exists."
        Stop-Transcript
        Exit 0
    }

    # Copy myself to a safe place if not already there
    if (-not (Test-Path "$dest\RenameComputer.ps1")) {
        Copy-Item $PSCommandPath "$dest\RenameComputer.PS1"
    }

    # Create the scheduled task action
    $action = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "-NoProfile -ExecutionPolicy bypass -WindowStyle Hidden -File $dest\RenameComputer.ps1"

    # Create the scheduled task trigger
    $timespan = New-Timespan -minutes 5
    $triggers = @()
    $triggers += New-ScheduledTaskTrigger -Daily -At 9am
    $triggers += New-ScheduledTaskTrigger -AtLogOn -RandomDelay $timespan
    $triggers += New-ScheduledTaskTrigger -AtStartup -RandomDelay $timespan
    
    # Register the scheduled task
    Register-ScheduledTask -User SYSTEM -Action $action -Trigger $triggers -TaskName "RenameComputer" -Description "RenameComputer" -Force
    Write-Host "Scheduled task created."
}

Stop-Transcript
