<#
.SYNOPSIS
    Renames computer based on network location and serial number.
.DESCRIPTION
    This script detects the computer's network location using IP addressing
    and renames it according to site-specific naming conventions.
.PARAMETER TestMode
    Runs the script without making actual changes.
.NOTES
    Version: 1.0
    Created: 2025-01-03
    Author: Adam Gell
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$TestMode
)

# Configuration
$LogFileName = "RenameComputer.log"
$PROGRAM_DATA_PATH = "$($env:ProgramData)\Microsoft\IntuneManagementExtension\Logs\"
$TAG_FILE = "$PROGRAM_DATA_PATH\RenameComputer.ps1.tag"


function Ensure-LogDirectory {
    if (-not (Test-Path $PROGRAM_DATA_PATH)) {
        try {
            New-Item -Path $PROGRAM_DATA_PATH -ItemType Directory -Force | Out-Null
            Write-Host "Created log directory: $PROGRAM_DATA_PATH" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to create log directory: $($_.Exception.Message)"
            Exit 1
        }
    }
}

Ensure-LogDirectory

# Logging Function
function Write-LogEntry {
    param (
        [parameter(Mandatory = $true, HelpMessage = "Value added to the log file.")]
        [ValidateNotNullOrEmpty()]
        [string]$Value,
        [parameter(Mandatory = $true, HelpMessage = "Severity for the log entry. 1 for Informational, 2 for Warning and 3 for Error.")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("1", "2", "3")]
        [string]$Severity,
        [parameter(Mandatory = $false, HelpMessage = "Name of the log file that the entry will written to.")]
        [ValidateNotNullOrEmpty()]
        [string]$FileName = $LogFileName
    )
    

    # Determine log file location
    $LogFilePath = Join-Path -Path $PROGRAM_DATA_PATH -ChildPath $FileName

    
	
    # Construct time stamp for log entry
    $Time = -join @((Get-Date -Format "HH:mm:ss.fff"), " ", (Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias))
	
    # Construct date for log entry
    $Date = (Get-Date -Format "MM-dd-yyyy")
	
    # Construct context for log entry
    $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
	
    # Construct final log entry
    $LogText = "<![LOG[$($Value)]LOG]!><time=""$($Time)"" date=""$($Date)"" component=""$($LogFileName)"" context=""$($Context)"" type=""$($Severity)"" thread=""$($PID)"" file="""">"
	
    # Display to console with appropriate coloring
    switch ($Severity) {
        "1" { Write-Host $Value -ForegroundColor Green }  # Information
        "2" { Write-Host $Value -ForegroundColor Yellow } # Warning
        "3" { Write-Host $Value -ForegroundColor Red }    # Error
    }

    # Add value to log file
    try {
        Out-File -InputObject $LogText -Append -NoClobber -Encoding Default -FilePath $LogFilePath -ErrorAction Stop
    }
    catch [System.Exception] {
        Write-Warning -Message "Unable to append log entry to $LogFileName.log file. Error message at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
    }

}

function Test-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-LogEntry -Value "Script requires administrative privileges" -Severity 3
        return $false
    }
    Write-LogEntry -Value "Script running with administrative privileges" -Severity 1
}

Test-AdminPrivileges

# Site Configuration
$SITE_CONFIG = @{
    'GELL' = @{
        SubnetPrefix = '192.168.2'
        WanIP        = '67.146.4.126'
        NamePrefix   = 'GELL-'
    }
    'NYC'  = @{
        SubnetPrefix = '10.1.0'
        WanIP        = '203.0.113.1'
        NamePrefix   = 'NYC-'
    }
    'LAX'  = @{
        SubnetPrefix = '10.2.0'
        WanIP        = '203.0.113.2'
        NamePrefix   = 'LAX-'
    }
    'ZZZ'  = @{
        SubnetPrefix = '*'
        WanIP        = '*'
        NamePrefix   = 'ZZZ-'
    }
}

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [ScriptBlock]$ScriptBlock,
        
        [Parameter(Mandatory = $false)]
        [string]$OperationName = "Operation",
        
        [Parameter(Mandatory = $false)]
        [int]$MaxAttempts = 3,
        
        [Parameter(Mandatory = $false)]
        [int]$DelaySeconds = 5
    )
    
    $attempt = 1
    $lastError = $null
    
    while ($attempt -le $MaxAttempts) {
        try {
            Write-LogEntry -Value "$OperationName - Attempt $attempt of $MaxAttempts" -Severity 1
            $result = & $ScriptBlock
            
            # If we get here, the operation succeeded
            if ($attempt -gt 1) {
                Write-LogEntry -Value "$OperationName succeeded on attempt $attempt" -Severity 1
            }
            return $result
        }
        catch {
            $lastError = $_
            if ($attempt -eq $MaxAttempts) {
                Write-LogEntry -Value "$OperationName failed after $MaxAttempts attempts. Last error: $($lastError.Exception.Message)" -Severity 3
                throw $lastError
            }
            
            Write-LogEntry -Value "$OperationName failed on attempt $attempt. Error: $($lastError.Exception.Message)" -Severity 2
            Write-LogEntry -Value "Waiting $DelaySeconds seconds before retry..." -Severity 2
            Start-Sleep -Seconds $DelaySeconds
            $attempt++
        }
    }
}

$EXCLUDED_ADAPTERS = @(
    'VMware',
    'VirtualBox',
    'Hyper-V',
    'WSL',
    'Bluetooth',
    'npcap',
    'Loopback'
)

function Get-CurrentNetworkInfo {
    try {
        $excludePattern = ($EXCLUDED_ADAPTERS -join '|')
        $lanIP = (Get-NetIPAddress -AddressFamily IPv4 | 
            Where-Object {
                $_.InterfaceAlias -notmatch $excludePattern -and 
                $_.ValidLifetime -and 
                $_.IPAddress -notmatch '^(169\.254\.|127\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|100\.)'
            } | 
            Sort-Object -Property @{Expression={$_.PrefixOrigin -eq 'Dhcp'}; Descending=$true} | 
            Select-Object -First 1).IPAddress

        if (-not $lanIP) {
            Write-LogEntry -Value "No valid LAN IP found" -Severity 3
            return $null
        }

        Write-LogEntry -Value "Found LAN IP: $lanIP" -Severity 1
        $wanIP = (Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing -TimeoutSec 10).Content.Trim()
        
        if (-not $wanIP) {
            Write-LogEntry -Value "Could not determine WAN IP" -Severity 3
            return $null
        }

        Write-LogEntry -Value "Found WAN IP: $wanIP" -Severity 1
        return @{
            LanIP = $lanIP
            WanIP = $wanIP
        }
    }
    catch {
        Write-LogEntry -Value "Network error: $($_.Exception.Message)" -Severity 3
        return $null
    }
}

function Get-RandomSerialNumber {
    # Generate 7 random characters (letters and numbers) and prepend 'Z'
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    $serial = 'Z' + -join (1..7 | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    return $serial
}

function Get-SiteFromSubnet {
    param ($LanIP, $WanIP)
    
    Write-LogEntry -Value "Checking site match for LAN IP: $LanIP, WAN IP: $WanIP" -Severity 1
    
    # First try to match specific sites (excluding ZZZ)
    foreach ($site in $SITE_CONFIG.Keys | Where-Object { $_ -ne 'ZZZ' }) {
        $config = $SITE_CONFIG[$site]
        $ipParts = $LanIP.Split('.')
        $prefixParts = $config.SubnetPrefix.Split('.')
        
        $isMatch = $true
        for ($i = 0; $i -lt $prefixParts.Count; $i++) {
            if ($ipParts[$i] -ne $prefixParts[$i]) {
                $isMatch = $false
                break
            }
        }
        
        if ($isMatch) {
            Write-LogEntry -Value "Found matching site: $site" -Severity 1
            return @{
                SiteName = $site
                IsWanMatch = ($WanIP -eq $config.WanIP)
                NamePrefix = $config.NamePrefix
            }
        }
    }
    
    # If nothing matches, use ZZZ (catch-all)
    Write-LogEntry -Value "No specific site match found, using ZZZ catch-all" -Severity 2
    return @{
        SiteName = 'ZZZ'
        IsWanMatch = $true  # Always consider WAN IP as matching for ZZZ
        NamePrefix = $SITE_CONFIG['ZZZ'].NamePrefix
    }
}

function Get-MachineSerialNumber {
    try {
        $serialNumber = (Get-WmiObject -Class Win32_BIOS).SerialNumber
        
        if ([string]::IsNullOrEmpty($serialNumber)) {
            Write-LogEntry -Value "Serial number is empty or null, generating random serial" -Severity 2
            return Get-RandomSerialNumber
        }
        
        if ($serialNumber -eq 'System Serial Number') {
            Write-LogEntry -Value "Non-unique serial number detected, generating random serial" -Severity 2
            return Get-RandomSerialNumber
        }

        # Remove any special characters and spaces
        $cleanSerialNumber = $serialNumber -replace '[^\w-]', ''
        
        if ($cleanSerialNumber -ne $serialNumber) {
            Write-LogEntry -Value "Cleaned serial number from '$serialNumber' to '$cleanSerialNumber'" -Severity 2
        }

        return $cleanSerialNumber
    }
    catch {
        Write-LogEntry -Value "Error getting serial number: $($_.Exception.Message)" -Severity 3
        return Get-RandomSerialNumber
    }
}

function Rename-ComputerBySite {
    try {
        if ($TestMode) {
            Write-LogEntry -Value "RUNNING IN TEST MODE - No changes will be made" -Severity 2
        }

        $currentComputerName = $env:ComputerName
        Write-LogEntry -Value "Current computer name: $currentComputerName" -Severity 1

        $networkInfo = Get-CurrentNetworkInfo
        if (-not $networkInfo) {
            Write-LogEntry -Value "Failed to get network information" -Severity 3
            return $false
        }

        $siteInfo = Get-SiteFromSubnet -LanIP $networkInfo.LanIP -WanIP $networkInfo.WanIP
        if (-not $siteInfo) {
            Write-LogEntry -Value "No matching site found" -Severity 3
            return $false
        }

        if (-not $siteInfo.IsWanMatch) {
            Write-LogEntry -Value "WAN IP mismatch detected - possible remote setup" -Severity 2
            return $false
        }

        $serialNumber = Get-MachineSerialNumber
        if (-not $serialNumber) {
            Write-LogEntry -Value "Unable to get valid serial number" -Severity 3
            return $false
        }
        Write-LogEntry -Value "Retrieved serial number: $serialNumber" -Severity 1
        
        $newName = "$($siteInfo.NamePrefix)$serialNumber"
        
        if ($newName.Length -gt 15) {
            $newName = $newName.Substring(0, 15)
            Write-LogEntry -Value "Name exceeded 15 characters, truncated to: $newName" -Severity 2
        }

        $newName = $newName -replace '[^a-zA-Z0-9-]', ''

        if ($newName -eq $currentComputerName) {
            Write-LogEntry -Value "Computer name already correct: $currentComputerName" -Severity 1
            return $true
        }

        Write-LogEntry -Value "New computer name will be: $newName" -Severity 1
        if (-not $TestMode) {
            try {
                Rename-Computer -NewName $newName -Force -ErrorAction Stop
                Set-Content -Path $TAG_FILE -Value 'Installed'
                Write-LogEntry -Value "Computer successfully renamed to: $newName" -Severity 1
            }
            catch {
                Write-LogEntry -Value "Failed to rename computer: $($_.Exception.Message)" -Severity 3
                return $false
            }
        }
        else {
            Write-LogEntry -Value "TEST MODE: Would rename computer to: $newName" -Severity 2
        }
        
        return $true
    }
    catch {
        Write-LogEntry -Value "Error in rename process: $($_.Exception.Message)" -Severity 3
        return $false
    }
}

# Main Execution
if ($TestMode) {
    Write-LogEntry -Value "Script started in TEST MODE" -Severity 2
}
else {
    Write-LogEntry -Value "Script started in PRODUCTION MODE" -Severity 1
}

try {
    $result = Rename-ComputerBySite
    if ($result) {
        Write-LogEntry -Value "Script completed successfully" -Severity 1
        Exit 1641  # Success, reboot required
    }
    Write-LogEntry -Value "Script completed with non-fatal errors" -Severity 2
    Exit 1
}
catch {
    Write-LogEntry -Value "Fatal error in script execution: $($_.Exception.Message)" -Severity 3
    Exit 1
}