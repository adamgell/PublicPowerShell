<# 

.DESCRIPTION 
 Rename the computer 

#> 

Param()

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
Start-Transcript "$dest\RenameComputer.log" -Append

# Make sure we are already domain-joined
$goodToGo = $true
$details = Get-ComputerInfo
if (-not $details.CsPartOfDomain) {
    Write-Host "Not part of a domain."
    $goodToGo = $false
}

# Make sure we have connectivity
$dcInfo = [ADSI]"LDAP://RootDSE"
if ($dcInfo.dnsHostName -eq $null) {
    Write-Host "No connectivity to the domain."
    $goodToGo = $false
}

if ($goodToGo) {
    # Get the new computer name
    # Retrieve system enclosure information
    $systemEnclosure = Get-CimInstance -ClassName Win32_SystemEnclosure

    # Determine the asset tag
    if (($null -eq $systemEnclosure.SMBIOSAssetTag) -or ($systemEnclosure.SMBIOSAssetTag -eq "")) {
        # Handle PowerShell 5.1 bug
        if ($null -ne $details.BiosSerialNumber) {
            $assetTag = $details.BiosSerialNumber
        }
        else {
            $assetTag = $details.BiosSerialNumber
        }
    }
    else {
        $assetTag = $systemEnclosure.SMBIOSAssetTag
    }

    # Get the current computer name and process it
    $currentComputerName = $env:ComputerName
    $tempComputerName = $currentComputerName.Split('-')
    $assetTag = $assetTag.Replace("-", "")

    # Trim the asset tag if it's longer than 12 characters
    if ($assetTag.Length -gt 12) {
        $serial = $assetTag.Substring(0, 10)
    }
    else {
        $serial = $assetTag
    }

    # Construct the new computer name
    $temp = $tempComputerName[0]
    $newName = "$temp-$serial"

    # Display and set the new computer name
    Write-Host "Renaming computer to $($newName)"

    $newName.Length

    Rename-Computer -NewName $newName

    # Remove the scheduled task
    Disable-ScheduledTask -TaskName "RenameComputer" -ErrorAction Ignore
    Unregister-ScheduledTask -TaskName "RenameComputer" -Confirm:$false -ErrorAction Ignore
    Write-Host "Scheduled task unregistered."

    # Make sure we reboot if still in ESP/OOBE by reporting a 1641 return code (hard reboot)
    if ($details.CsUserName -match "defaultUser") {
        Write-Host "Exiting during ESP/OOBE with return code 1641"
        Stop-Transcript
        Exit 1641
    }
    else {
        Write-Host "Initiating a restart in 1 minute"
        & shutdown.exe /g /t 60 /f /c "Restarting the computer in 1 mintue due to a computer name change.  Save your work."
        Stop-Transcript
        Exit 0
    }
}
else {
    # Check to see if already scheduled
    $existingTask = Get-ScheduledTask -TaskName "RenameComputer" -ErrorAction SilentlyContinue
    if ($existingTask -ne $null) {
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
