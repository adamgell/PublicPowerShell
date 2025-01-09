<#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Renames computer based on network location and serial number.
.DESCRIPTION
    This script detects the computer's network location using IP addressing
    and renames it according to site-specific naming conventions.
.PARAMETER TestMode
    Runs the script without making actual changes.
.NOTES
    Version: 2.0
    Created: 2025-01-07
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

# Site Configuration
$SITE_CONFIG = @{
    'REMOTE' = @{
        SubnetPrefix = '*'  # Wildcard for any subnet
        WanIP = '*'        # Wildcard for any WAN IP
        TimeZone = 'Auto'
        IsRemote = $true
        NamingPattern = 'Special'
        NamePrefix = 'JO'
    }
    'ALPHARETTA' = @{
        SubnetPrefix = '10.10.0'
        WanIP = '203.0.113.10'
        TimeZone = 'Eastern Standard Time'
        NamingPattern = 'Full'
        NamePrefix = 'AL'
    }
    'ANTIBES' = @{
        SubnetPrefix = '10.20.0'
        WanIP = '203.0.113.20'
        TimeZone = 'Central European Standard Time'
        NamingPattern = 'Partial'
        NamePrefix = 'ANT'
    }
    'BATAM' = @{
        SubnetPrefix = '10.30.0'
        WanIP = '203.0.113.30'
        TimeZone = 'Western Indonesian Time'
        NamingPattern = 'Partial'
        NamePrefix = 'BAT'
    }
    'BINGHAMTON' = @{
        SubnetPrefix = '10.40.0'
        WanIP = '203.0.113.40'
        TimeZone = 'Eastern Standard Time'
        NamingPattern = 'Full'
        NamePrefix = 'BI'
    }
    'BURLINGTON' = @{
        SubnetPrefix = '10.50.0'
        WanIP = '203.0.113.50'
        TimeZone = 'Eastern Standard Time'
        NamingPattern = 'Full'
        NamePrefix = 'BU'
    }
    'CASARZA' = @{
        SubnetPrefix = '10.60.0'
        WanIP = '203.0.113.60'
        TimeZone = 'Central European Standard Time'
        NamingPattern = 'Partial'
        NamePrefix = 'CAS'
    }
    'DURBAN' = @{
        SubnetPrefix = '10.70.0'
        WanIP = '203.0.113.70'
        TimeZone = 'South Africa Standard Time'
        NamingPattern = 'Partial'
        NamePrefix = 'DUR'
    }
    'EL_CAJON' = @{
        SubnetPrefix = '10.80.0'
        WanIP = '203.0.113.80'
        TimeZone = 'Pacific Standard Time'
        NamingPattern = 'Full'
        NamePrefix = 'EC'
    }
    'EUFAULA' = @{
        SubnetPrefix = '10.90.0'
        WanIP = '203.0.113.90'
        TimeZone = 'Central Standard Time'
        NamingPattern = 'Full'
        NamePrefix = 'EU'
    }
    'LITTLE_FALLS' = @{
        SubnetPrefix = '10.100.0'
        WanIP = '203.0.113.100'
        TimeZone = 'Central Standard Time'
        NamingPattern = 'Full'
        NamePrefix = 'LF'
    }
    'MANKATO' = @{
        SubnetPrefix = '10.110.0'
        WanIP = '203.0.113.110'
        TimeZone = 'Central Standard Time'
        NamingPattern = 'Full'
        NamePrefix = 'MA'
    }
    'MEXICALI' = @{
        SubnetPrefix = '10.120.0'
        WanIP = '203.0.113.120'
        TimeZone = 'Pacific Standard Time'
        NamingPattern = 'Full'
        NamePrefix = 'ME'
    }
    'NUREMBERG' = @{
        SubnetPrefix = '10.130.0'
        WanIP = '203.0.113.130'
        TimeZone = 'Central European Standard Time'
        NamingPattern = 'Partial'
        NamePrefix = 'NUR'
    }
    'OLD_TOWN' = @{
        SubnetPrefix = '10.140.0'
        WanIP = '203.0.113.140'
        TimeZone = 'Eastern Standard Time'
        NamingPattern = 'Full'
        NamePrefix = 'OT'
    }
    'RACINE' = @{
        SubnetPrefix = '10.150.0'
        WanIP = '203.0.113.150'
        TimeZone = 'Central Standard Time'
        NamingPattern = 'Full'
        NamePrefix = 'RA'
    }
    'TORONTO' = @{
        SubnetPrefix = '10.160.0'
        WanIP = '203.0.113.160'
        TimeZone = 'Eastern Standard Time'
        NamingPattern = 'Full'
        NamePrefix = 'TO'
    }
    'SPREITENBACH' = @{
        SubnetPrefix = '10.170.0'
        WanIP = '203.0.113.170'
        TimeZone = 'Central European Standard Time'
        NamingPattern = 'Partial'
        NamePrefix = 'SPR'
    }
    'HONG_KONG' = @{
        SubnetPrefix = '10.180.0'
        WanIP = '203.0.113.180'
        TimeZone = 'China Standard Time'
        NamingPattern = 'Partial'
        NamePrefix = 'HON'
    }
    'CHATSWOOD' = @{
        SubnetPrefix = '10.190.0'
        WanIP = '203.0.113.190'
        TimeZone = 'AUS Eastern Standard Time'
        NamingPattern = 'Partial'
        NamePrefix = 'CHA'
    }
}
# endregion

# Excluded network adapters
$EXCLUDED_ADAPTERS = @(
    'VMware',
    'VirtualBox',
    'Hyper-V',
    'WSL',
    'Bluetooth',
    'npcap',
    'Loopback'
)


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

function Write-LogEntry {
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Value,
        [parameter(Mandatory = $true)]
        [ValidateSet("1", "2", "3")]
        [string]$Severity,
        [parameter(Mandatory = $false)]
        [string]$FileName = $LogFileName
    )

    $LogFilePath = Join-Path -Path $PROGRAM_DATA_PATH -ChildPath $FileName
    $Time = -join @((Get-Date -Format "HH:mm:ss.fff"), " ", (Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias))
    $Date = (Get-Date -Format "MM-dd-yyyy")
    $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
    $LogText = "<![LOG[$($Value)]LOG]!><time=""$($Time)"" date=""$($Date)"" component=""$($LogFileName)"" context=""$($Context)"" type=""$($Severity)"" thread=""$($PID)"" file="""">"
    
    switch ($Severity) {
        "1" { Write-Host $Value -ForegroundColor Green }
        "2" { Write-Host $Value -ForegroundColor Yellow }
        "3" { Write-Host $Value -ForegroundColor Red }
    }

    try {
        Out-File -InputObject $LogText -Append -NoClobber -Encoding Default -FilePath $LogFilePath -ErrorAction Stop
    }
    catch [System.Exception] {
        Write-Warning -Message "Unable to append log entry to $LogFileName.log file. Error message: $($_.Exception.Message)"
    }
}

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [ScriptBlock]$ScriptBlock,
        [string]$OperationName = "Operation",
        [int]$MaxAttempts = 3,
        [int]$DelaySeconds = 5
    )
    
    $attempt = 1
    while ($attempt -le $MaxAttempts) {
        try {
            Write-LogEntry -Value "$OperationName - Attempt $attempt of $MaxAttempts" -Severity 1
            $result = & $ScriptBlock
            if ($attempt -gt 1) {
                Write-LogEntry -Value "$OperationName succeeded on attempt $attempt" -Severity 1
            }
            return $result
        }
        catch {
            if ($attempt -eq $MaxAttempts) {
                Write-LogEntry -Value "$OperationName failed after $MaxAttempts attempts. Last error: $($_.Exception.Message)" -Severity 3
                throw
            }
            Write-LogEntry -Value "$OperationName failed on attempt $attempt. Error: $($_.Exception.Message)" -Severity 2
            Start-Sleep -Seconds $DelaySeconds
            $attempt++
        }
    }
}

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

function Get-MachineSerialNumber {
    try {
        $serialNumber = (Get-WmiObject -Class Win32_BIOS).SerialNumber
        
        if ([string]::IsNullOrEmpty($serialNumber)) {
            Write-LogEntry -Value "Serial number is empty or null, generating random serial" -Severity 2
            return Get-RandomSerialNumber
        }
        
        if ($serialNumber -eq 'System Serial Number') {
            return Get-RandomSerialNumber
        }

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

function Get-RandomSerialNumber {
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    $serial = 'Z' + -join (1..7 | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    return $serial
}

function Get-SiteFromSubnet {
    param ($LanIP, $WanIP)
    
    Write-LogEntry -Value "Checking site match for LAN IP: $LanIP, WAN IP: $WanIP" -Severity 1
    
    foreach ($site in $SITE_CONFIG.Keys | Where-Object { $_ -ne 'REMOTE' }) {
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
    
    Write-LogEntry -Value "No specific site match found, using REMOTE" -Severity 2
    return @{
        SiteName = 'REMOTE'
        IsWanMatch = $true
        NamePrefix = $SITE_CONFIG['REMOTE'].NamePrefix
    }
}

function Get-ComputerNameTemplate {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Site,
        [Parameter(Mandatory = $true)]
        [string]$SerialNumber,
        [Parameter(Mandatory = $true)]
        [bool]$IsLaptop
    )
    
    try {
        $siteConfig = $SITE_CONFIG[$Site]
        if (-not $siteConfig) {
            throw "Unknown site: $Site"
        }

        $basePrefix = $siteConfig.NamePrefix
        $fullPrefix = if ($IsLaptop) {
            "${basePrefix}LT-"
        } else {
            "${basePrefix}PC-"
        }

        $newName = "$fullPrefix$SerialNumber"
        
        if ($newName.Length -gt 15) {
            Write-LogEntry -Value "Name exceeded 15 characters, truncating: $newName" -Severity 2
            $newName = $newName.Substring(0, 15)
        }
        
        $newName = $newName -replace '[^a-zA-Z0-9-]', ''
        return $newName
    }
    catch {
        Write-LogEntry -Value "Error generating computer name: $_" -Severity 3
        throw
    }
}

function Show-SiteConfig {
    param (
        [Parameter(Mandatory = $false)]
        [switch]$Raw
    )
    
    $siteData = foreach ($site in $SITE_CONFIG.GetEnumerator()) {
        $sortableIP = if ($site.Value.SubnetPrefix -eq '*') {
            0
        } else {
            $octets = $site.Value.SubnetPrefix.Split('.')
            [int]($octets[0]).ToString().PadLeft(3,'0') * 1000000 +
            [int]($octets[1]).ToString().PadLeft(3,'0') * 1000 +
            [int]($octets[2]).ToString().PadLeft(3,'0')
        }

        [PSCustomObject]@{
            'Site' = $site.Name
            'SubnetPrefix' = $site.Value.SubnetPrefix
            'WAN_IP' = $site.Value.WanIP
            'NamePrefix' = $site.Value.NamePrefix
            'SortableIP' = $sortableIP
        }
    }

    if ($Raw) {
        return $siteData
    }
    else {
        Write-LogEntry -Value ("=" * 160) -Severity 1
        Write-LogEntry -Value "Site Configuration Table" -Severity 1
        Write-LogEntry -Value ("=" * 160) -Severity 1
        
        $siteData | 
            Sort-Object SortableIP | 
            Select-Object -Property * -ExcludeProperty SortableIP |
            Format-Table -AutoSize -Wrap | 
            Out-String -Width 120 | 
            ForEach-Object { Write-LogEntry -Value $_ -Severity 1 }
        
        Write-LogEntry -Value ("=" * 160) -Severity 1
    }
}

function Test-AllSitePatterns {
    param (
        [Parameter(Mandatory = $false)]
        [switch]$IncludeNetwork = $false
    )
    
    $sites = $SITE_CONFIG.Keys | Sort-Object
    
    foreach ($site in $sites) {
        Write-LogEntry -Value ("=" * 42) -Severity 1
        Write-LogEntry -Value "Testing Site: $site" -Severity 1
        Write-LogEntry -Value ("=" * 42) -Severity 1
        
        $config = $SITE_CONFIG[$site]
        
        if ($IncludeNetwork) {
            Write-LogEntry -Value "Network Configuration:" -Severity 1
            Write-LogEntry -Value "  Subnet Prefix: $($config.SubnetPrefix)" -Severity 1
            Write-LogEntry -Value "  WAN IP: $($config.WanIP)" -Severity 1
            Write-LogEntry -Value ("-" * 40) -Severity 1
        }
        
        foreach ($deviceType in @('Desktop', 'Laptop')) {
            $serialNumber = Get-MachineSerialNumber
            $isLaptop = $deviceType -eq 'Laptop'
            
            try {
                $computerName = Get-ComputerNameTemplate -Site $site -SerialNumber $serialNumber -IsLaptop $isLaptop
                Write-LogEntry -Value "     [$deviceType] Name Template: $computerName" -Severity 1
            }
            catch {
                Write-LogEntry -Value "[$deviceType] Error testing site $site : $($_.Exception.Message)" -Severity 3
            }
        }
        
        if (-not ($site -eq $sites[-1])) {
            Write-LogEntry -Value ("-" * 40) -Severity 1
        }
    }
    
    Write-LogEntry -Value ("=" * 42) -Severity 1
}

# Example usage:
Test-AllSitePatterns
# Test-AllSitePatterns -IncludeNetwork  # To include network details

Show-SiteConfig