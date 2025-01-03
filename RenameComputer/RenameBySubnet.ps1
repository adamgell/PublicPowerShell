# Computer Rename Script
# Purpose: Renames computers based on site location determined by subnet and WAN IP

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$TestMode
)

#region Configuration
$PROGRAM_DATA_PATH = "$($env:ProgramData)\Microsoft\RenameComputer"
$LOG_FILE = "$PROGRAM_DATA_PATH\RenameComputer.log"
$TAG_FILE = "$PROGRAM_DATA_PATH\RenameComputer.ps1.tag"

# Site Configuration - Add all sites here
$SITE_CONFIG = @{
    'NYC' = @{
        SubnetPrefix = '10.1.0'
        WanIP = '203.0.113.1'
        NamePrefix = 'NYC-'
    }
    'LAX' = @{
        SubnetPrefix = '10.2.0'
        WanIP = '203.0.113.2'
        NamePrefix = 'LAX-'
    }
    # Add more sites as needed
}
#endregion

#region Logging Functions
function Write-Log {
    param([string]$Message)
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Write-Host $logMessage
    if ($Script:IsTranscribing) {
        $logMessage | Out-File -FilePath $LOG_FILE -Append
    }
}

# Initialize logging
$Script:IsTranscribing = $false
if (-not ($env:PESTER_TEST_RUN)) {
    if (-not (Test-Path $PROGRAM_DATA_PATH)) {
        New-Item -Path $PROGRAM_DATA_PATH -ItemType Directory -Force | Out-Null
    }
    Start-Transcript $LOG_FILE -Append
    $Script:IsTranscribing = $true
}
Write-Log "Script execution started"
#endregion

#region Network Functions
function Get-CurrentNetworkInfo {
    try {
        # Get all IPv4 addresses
        $allIPs = Get-NetIPAddress -AddressFamily IPv4 | 
                  Where-Object { 
                      $_.InterfaceAlias -notmatch 'Loopback' -and 
                      $_.IPAddress -notmatch '^169.254.' -and
                      $_.IPAddress -notmatch '^127\.'
                  }

        # Get primary LAN IP
        $lanIP = ($allIPs | Sort-Object InterfaceMetric | Select-Object -First 1).IPAddress
        
        if (-not $lanIP) {
            throw "No valid LAN IP found"
        }

        Write-Log "Found LAN IP: $lanIP"

        # Get WAN IP using multiple services for redundancy
        $wanIP = $null
        $wanServices = @(
            'https://api.ipify.org',
            'https://ifconfig.me/ip',
            'https://icanhazip.com'
        )

        foreach ($service in $wanServices) {
            try {
                $wanIP = (Invoke-WebRequest -Uri $service -UseBasicParsing -TimeoutSec 10).Content.Trim()
                if ($wanIP -match '^(\d{1,3}\.){3}\d{1,3}$') {
                    Write-Log "Found WAN IP: $wanIP"
                    break
                }
            }
            catch {
                Write-Log "Failed to get WAN IP from $service"
                continue
            }
        }

        if (-not $wanIP) {
            throw "Could not determine WAN IP from any service"
        }

        return @{
            LanIP = $lanIP
            WanIP = $wanIP
        }
    }
    catch {
        Write-Log "Error getting network information: $_"
        return $null
    }
}

function Get-SiteFromSubnet {
    param (
        [Parameter(Mandatory=$true)]
        [string]$LanIP,
        [Parameter(Mandatory=$true)]
        [string]$WanIP
    )

    Write-Log "Checking site match for LAN IP: $LanIP, WAN IP: $WanIP"

    foreach ($site in $SITE_CONFIG.Keys) {
        $config = $SITE_CONFIG[$site]
        if ($LanIP.StartsWith($config.SubnetPrefix)) {
            $result = @{
                SiteName = $site
                IsWanMatch = ($WanIP -eq $config.WanIP)
                NamePrefix = $config.NamePrefix
            }
            Write-Log "Found matching site: $site (WAN Match: $($result.IsWanMatch))"
            return $result
        }
    }
    
    Write-Log "No matching site found for subnet"
    return $null
}
#endregion

#region System Validation Functions
function Test-SystemRequirements {
    # Ensure 64-bit PowerShell
    if ("$env:PROCESSOR_ARCHITECTURE" -ne "AMD64") {
        if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe") {
            Write-Log "Relaunching script in 64-bit PowerShell"
            & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy bypass -File "$PSCommandPath"
            Exit $lastexitcode
        }
    }

    # Get computer info
    try {
        $details = Get-ComputerInfo
        Write-Log "Successfully retrieved computer information"
        return $details
    }
    catch {
        Write-Log "Error retrieving computer information: $_"
        throw
    }
}

function Test-DomainStatus {
    param($computerInfo)
    
    if (-not $computerInfo.CsPartOfDomain) {
        Write-Log "This computer is not part of a traditional domain. Checking Azure AD join status..."
        
        try {
            $dsregStatus = & dsregcmd /status
            $isAzureADJoined = $dsregStatus | Select-String "AzureAdJoined : YES"
            
            if (-not $isAzureADJoined) {
                Write-Log "Device is neither domain joined nor Azure AD joined. Renaming cannot proceed."
                return $false
            }
            
            Write-Log "Device is Azure AD joined. Proceeding with rename process..."
            
            $testConnection = Test-NetConnection login.microsoftonline.com -Port 443
            if (-not $testConnection.TcpTestSucceeded) {
                Write-Log "Unable to establish connectivity to Azure AD. Please check network settings."
                return $false
            }
            Write-Log "Successfully verified Azure AD connectivity"
            return $true
        }
        catch {
            Write-Log "Error checking Azure AD join status: $_"
            return $false
        }
    }
    else {
        try {
            $dcInfo = [ADSI]"LDAP://RootDSE"
            if ($null -eq $dcInfo.dnsHostName) {
                Write-Log "Unable to establish connectivity to the domain. Please check network settings."
                return $false
            }
            Write-Log "Successfully connected to domain controller: $($dcInfo.dnsHostName)"
            return $true
        }
        catch {
            Write-Log "Error checking domain connectivity: $_"
            return $false
        }
    }
}
#endregion

#region Main Execution
function Rename-ComputerBySite {
    if ($TestMode) {
        Write-Log "RUNNING IN TEST MODE - No changes will be made"
    }
    try {
        $computerInfo = Test-SystemRequirements
        if (-not (Test-DomainStatus $computerInfo)) {
            Write-Log "Domain validation failed. Exiting."
            return $false
        }

        $currentComputerName = $env:ComputerName
        Write-Log "Current computer name: $currentComputerName"

        $networkInfo = Get-CurrentNetworkInfo
        if (-not $networkInfo) {
            Write-Log "Failed to get network information. Exiting."
            return $false
        }

        $siteInfo = Get-SiteFromSubnet -LanIP $networkInfo.LanIP -WanIP $networkInfo.WanIP
        if (-not $siteInfo) {
            Write-Log "Computer is not in a known office subnet. Exiting."
            return $false
        }

        if (-not $siteInfo.IsWanMatch) {
            Write-Log "WARNING: Computer has office subnet but incorrect WAN IP. Possible remote setup."
            return $false
        }

        # Generate new name using site prefix and serial number
        $serialNumber = (Get-WmiObject -Class Win32_BIOS).SerialNumber
        Write-Log "Retrieved serial number: $serialNumber"
        
        $newName = "$($siteInfo.NamePrefix)$serialNumber"
        
        # Ensure name meets Windows computer name requirements
        if ($newName.Length -gt 15) {
            $newName = $newName.Substring(0, 15)
            Write-Log "New name exceeded 15 characters. Truncated to: $newName"
        }

        # Remove any invalid characters
        $newName = $newName -replace '[^a-zA-Z0-9-]', ''

        if ($newName -eq $currentComputerName) {
            Write-Log "Computer name is already correct. No action needed."
            Set-Content -Path $TAG_FILE -Value "Installed"
            return $true
        }

        Write-Log "Initiating computer rename to: $newName"
        if ($TestMode) {
            Write-Log "TEST MODE: Would rename computer to: $newName"
            Write-Log "TEST MODE: Would set TAG_FILE to: Installed"
        } else {
            Rename-Computer -NewName $newName -Force -ErrorAction Continue
            Set-Content -Path $TAG_FILE -Value "Installed"
        }
        
        Write-Log "Computer rename completed successfully. Reboot required."
        return $true
    }
    catch {
        Write-Log "Error during rename process: $_"
        return $false
    }
}

# Print test mode banner if enabled
if ($TestMode) {
    Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║           RUNNING IN TEST MODE         ║" -ForegroundColor Yellow
    Write-Host "║     No actual changes will be made     ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Yellow
}

# Main execution block
try {
    $result = Rename-ComputerBySite
    
    if ($Script:IsTranscribing) {
        Stop-Transcript
    }
    
    if ($result) {
        Exit 1641  # Signals success and requires reboot
    }
    else {
        Exit 1
    }
}
catch {
    Write-Log "Critical error in main execution: $_"
    if ($Script:IsTranscribing) {
        Stop-Transcript
    }
    Exit 1
}
#endregion