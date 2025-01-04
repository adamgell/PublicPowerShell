[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$TestMode
)

# Configuration
$PROGRAM_DATA_PATH = "$($env:ProgramData)\Microsoft\RenameComputer"
$LOG_FILE = "$PROGRAM_DATA_PATH\RenameComputer.log"
$TAG_FILE = "$PROGRAM_DATA_PATH\RenameComputer.ps1.tag"

# Site Configuration

$SITE_CONFIG = @{
    'DEFAULT' = @{
        SubnetPrefix = '192.168.2'
        WanIP = '67.146.4.126'
        NamePrefix = 'GELL-'
    }
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
    'ZZZ' = @{
        SubnetPrefix = '*'
        WanIP = '*'
        NamePrefix = 'ZZZ-'
    }
}

# Logging Function
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "$timestamp - $Message"
    Write-Host $logMessage
    if ($Script:IsTranscribing) {
        Add-Content -Path $LOG_FILE -Value $logMessage
    }
}

# Main Functions
function Get-CurrentNetworkInfo {
    try {
        $lanIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notmatch 'Loopback|WSL|VMware|VirtualBox|Default Switch' -and $_.ValidLifetime -and $_.IPAddress -notmatch '^(169\.254\.|127\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|100\.)'} | Sort-Object -Property @{Expression={$_.PrefixOrigin -eq 'Dhcp'}; Descending=$true} | Select-Object -First 1).IPAddress
        if (-not $lanIP) {
            Write-Log 'No valid LAN IP found'
            return $null
        }

        Write-Log "Found LAN IP: $lanIP"
        $wanIP = (Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing -TimeoutSec 10).Content.Trim()
        
        if (-not $wanIP) {
            Write-Log 'Could not determine WAN IP'
            return $null
        }

        Write-Log "Found WAN IP: $wanIP"
        return @{
            LanIP = $lanIP
            WanIP = $wanIP
        }
    }
    catch {
        Write-Log "Network error: $($_.Exception.Message)"
        return $null
    }
}

function Get-SiteFromSubnet {
    param ($LanIP, $WanIP)
    
    foreach ($site in $SITE_CONFIG.Keys) {
        $config = $SITE_CONFIG[$site]
        if ($LanIP.StartsWith($config.SubnetPrefix)) {
            return @{
                SiteName = $site
                IsWanMatch = ($WanIP -eq $config.WanIP)
                NamePrefix = $config.NamePrefix
            }
        }
    }
    return $null
}

function Rename-ComputerBySite {
    try {
        if ($TestMode) {
            Write-Log 'TEST MODE - No changes will be made'
        }

        $currentComputerName = $env:ComputerName
        Write-Log "Current name: $currentComputerName"

        $networkInfo = Get-CurrentNetworkInfo
        if (-not $networkInfo) {
            Write-Log 'Failed to get network information'
            return $false
        }

        $siteInfo = Get-SiteFromSubnet -LanIP $networkInfo.LanIP -WanIP $networkInfo.WanIP
        if (-not $siteInfo) {
            Write-Log 'No matching site found'
            return $false
        }

        if (-not $siteInfo.IsWanMatch) {
            Write-Log 'WAN IP mismatch detected'
            return $false
        }

        $serialNumber = (Get-WmiObject -Class Win32_BIOS).SerialNumber
        
        # lets make sure the serialnumber is not empty before we continue
        if ($null -eq $serialNumber -or $serialNumber -eq '') {
            Write-Log 'Serial number is empty or null'
            return $false
        }

        Write-Log "Serial number: $serialNumber"
        if($serialNumber -eq 'System Serial Number') {
            Write-Log 'Serial number is not unique. Setting a default serial number.'
            #lets set a default serial number
            $serialNumber = '1234567890'
        }
        $newName = "$($siteInfo.NamePrefix)$serialNumber"
        
        if ($newName.Length -gt 15) {
            $newName = $newName.Substring(0, 15)
        }

        $newName = $newName -replace '[^a-zA-Z0-9-]', ''

        if ($newName -eq $currentComputerName) {
            Write-Log 'Computer name already correct'
            return $true
        }

        Write-Log "New name will be: $newName"
        if (-not $TestMode) {
            Rename-Computer -NewName $newName -Force
            Set-Content -Path $TAG_FILE -Value 'Installed'
        }
        
        return $true
    }
    catch {
        Write-Log "Error: $($_.Exception.Message)"
        return $false
    }
}

# Main Execution
if ($TestMode) {
    Write-Host 'RUNNING IN TEST MODE - No changes will be made' -ForegroundColor Yellow
}

try {
    $result = Rename-ComputerBySite
    if ($result) {
        Exit 1641  # Success, reboot required
    }
    Exit 1
}
catch {
    Write-Log "Fatal error: $($_.Exception.Message)"
    Exit 1
}