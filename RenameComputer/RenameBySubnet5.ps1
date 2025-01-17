<#
.SYNOPSIS
    Renames computer based on site and hardware configuration.
.DESCRIPTION
    This script renames computers according to standardized naming conventions based on:
    - Site location (provided as parameter)
    - Device type (laptop/desktop)
    - Serial number
    Supports multiple naming patterns:
    - Full pattern (e.g., ALLT-/ALPC- for Alpharetta)
    - Partial pattern (e.g., CASL-/CASP- for Casarza)
    - Special pattern (e.g., JOLT-/JOPC- for Remote)
.PARAMETER Site
    The site code for the computer's location (e.g., "ALPHARETTA", "DURBAN")
.PARAMETER TestMode
    Runs the script without making actual changes
.EXAMPLE
    .\RenameComputer.ps1 -Site "DURBAN"
.EXAMPLE
    .\RenameComputer.ps1 -Site "ALPHARETTA" -TestMode
.NOTES
    Version: 2.0
    Created: 2025-01-06
    Author: Adam Gell
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ArgumentCompleter({
        param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
        
        # Get all site names from $SITE_CONFIG
        $siteNames = $SITE_CONFIG.Keys | Sort-Object
        
        if ([string]::IsNullOrEmpty($WordToComplete)) {
            return $siteNames
        }
        
        return $siteNames.Where({ $_ -like "$WordToComplete*" })
    })]
    [string]$Site,
    
    [Parameter(Mandatory = $false)]
    [switch]$TestMode
)

#region Configuration
$LogFileName = "RenameComputer.log"
$PROGRAM_DATA_PATH = "$($env:ProgramData)\Microsoft\IntuneManagementExtension\Logs\"
$TAG_FILE = "$PROGRAM_DATA_PATH\RenameComputer.ps1.tag"

# Site Configuration
$SITE_CONFIG = @{
    'REMOTE'       = @{
        SubnetPrefix  = '0.0.0.0'
        WanIP         = '0.0.0.0'
        TimeZone      = 'Auto'
        IsRemote      = $true
        NamingPattern = 'Special'
        SiteCode      = 'JO'
    }
    'ALPHARETTA'   = @{
        SubnetPrefix  = '10.111.0.0/16'
        WanIP         = '12.48.212.3/32'
        TimeZone      = 'Eastern Standard Time'
        NamingPattern = 'Full'
        SiteCode      = 'AL'
    }
    'ANTIBES'      = @{
        SubnetPrefix  = '10.200.0.0/16'
        WanIP         = '81.80.40.201/32'
        TimeZone      = 'Central European Standard Time'
        NamingPattern = 'Partial'
        SiteCode      = 'ANT'
    }
    'BATAM'        = @{
        SubnetPrefix  = 'TBD'
        WanIP         = '103.246.3.226/32'
        TimeZone      = 'Western Indonesian Time'
        NamingPattern = 'Partial'
        SiteCode      = 'BAT'
    }
    'BINGHAMTON'   = @{
        SubnetPrefix  = '10.2.0.0/16'
        WanIP         = '4.26.27.126/32'
        TimeZone      = 'Eastern Standard Time'
        NamingPattern = 'Full'
        SiteCode      = 'BI'
    }
    'BURLINGTON'   = @{
        SubnetPrefix  = '10.8.0.0/16'
        WanIP         = '45.78.180.162/32'
        TimeZone      = 'Eastern Standard Time'
        NamingPattern = 'Full'
        SiteCode      = 'BU'
    }
    'CASARZA'      = @{
        SubnetPrefix  = '10.202.0.0/16'
        WanIP         = '80.18.250.186/32'
        TimeZone      = 'Central European Standard Time'
        NamingPattern = 'Partial'
        SiteCode      = 'CAS'
    }
    'DURBAN'       = @{
        SubnetPrefix  = '10.121.0.0/16'
        WanIP         = 'TBD'
        TimeZone      = 'South Africa Standard Time'
        NamingPattern = 'Partial'
        SiteCode      = 'DUR'
    }
    'EL_CAJON'     = @{
        SubnetPrefix  = '10.5.0.0/16'
        WanIP         = '72.214.7.229/32'
        TimeZone      = 'Pacific Standard Time'
        NamingPattern = 'Full'
        SiteCode      = 'EC'
    }
    'EUFAULA'      = @{
        SubnetPrefix  = '10.110.0.0/16'
        WanIP         = '142.190.65.35/32'
        TimeZone      = 'Central Standard Time'
        NamingPattern = 'Full'
        SiteCode      = 'EU'
    }
    'LITTLE_FALLS' = @{
        SubnetPrefix  = '112.0.0/16'
        WanIP         = '69.168.254.36/32'
        TimeZone      = 'Central Standard Time'
        NamingPattern = 'Full'
        SiteCode      = 'LF'
    }
    'MANKATO'      = @{
        SubnetPrefix  = '10.4.0.0/16'
        WanIP         = '35.131.6.250/32'
        TimeZone      = 'Central Standard Time'
        NamingPattern = 'Full'
        SiteCode      = 'MA'
    }
    'MEXICALI'     = @{
        SubnetPrefix  = '10.3.0.0/16'
        WanIP         = '187.185.68.122/32'
        TimeZone      = 'Pacific Standard Time'
        NamingPattern = 'Full'
        SiteCode      = 'ME'
    }
    'NUREMBERG'    = @{
        SubnetPrefix  = '10.204.0.0/16'
        WanIP         = '80.155.138.130/32'
        TimeZone      = 'Central European Standard Time'
        NamingPattern = 'Partial'
        SiteCode      = 'NUR'
    }
    'OLD_TOWN'     = @{
        SubnetPrefix  = '10.7.0.0/16'
        WanIP         = '72.71.253.50/32'
        TimeZone      = 'Eastern Standard Time'
        NamingPattern = 'Full'
        SiteCode      = 'OT'
    }
    'RACINE'       = @{
        SubnetPrefix  = '10.1.0.0/16'
        WanIP         = '38.71.70.17/32'
        TimeZone      = 'Central Standard Time'
        NamingPattern = 'Full'
        SiteCode      = 'RA'
    }
    'TORONTO'      = @{
        SubnetPrefix  = '10.113.0.0/16'
        WanIP         = '72.139.62.27/32'
        TimeZone      = 'Eastern Standard Time'
        NamingPattern = 'Full'
        SiteCode      = 'TO'
    }
    'SPREITENBACH' = @{
        SubnetPrefix  = '10.203.0.0/16'
        WanIP         = '194.209.70.154/32'
        TimeZone      = 'Central European Standard Time'
        NamingPattern = 'Partial'
        SiteCode      = 'SPR'
    }
    'HONG_KONG'    = @{
        SubnetPrefix  = ''
        WanIP         = ''
        TimeZone      = 'China Standard Time'
        NamingPattern = 'Partial'
        SiteCode      = 'HON'
    }
    'CHATSWOOD'    = @{
        SubnetPrefix  = ''
        WanIP         = ''
        TimeZone      = 'AUS Eastern Standard Time'
        NamingPattern = 'Partial'
        SiteCode      = 'CHA'
    }
}
# endregion

#region Helper Functions
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

function Write-LogEntry {
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Value,
        
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("1", "2", "3")]
        [string]$Severity,
        
        [parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$FileName = $LogFileName,

        [parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$textcolor = "Green"
    )
    
    $LogFilePath = Join-Path -Path $PROGRAM_DATA_PATH -ChildPath $FileName
    $Time = -join @((Get-Date -Format "HH:mm:ss.fff"), " ", (Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias))
    $Date = (Get-Date -Format "MM-dd-yyyy")
    $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
    $LogText = "<![LOG[$($Value)]LOG]!><time=""$($Time)"" date=""$($Date)"" component=""$($LogFileName)"" context=""$($Context)"" type=""$($Severity)"" thread=""$($PID)"" file="""">"
    
    switch ($Severity) {
        "1" { Write-Host $Value -ForegroundColor $textcolor }
        "2" { Write-Host $Value -ForegroundColor Yellow }
        "3" { Write-Host $Value -ForegroundColor Red }
    }

    try {
        Out-File -InputObject $LogText -Append -NoClobber -Encoding Default -FilePath $LogFilePath -ErrorAction Stop
    }
    catch [System.Exception] {
        Write-Warning -Message "Unable to append log entry to $LogFileName.log file. Error message at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
    }
}

function Test-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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
            Write-LogEntry -Value "Waiting $DelaySeconds seconds before retry..." -Severity 2
            Start-Sleep -Seconds $DelaySeconds
            $attempt++
        }
    }
}

function Get-RandomSerialNumber {
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    $serial = 'Z' + -join (1..7 | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    return $serial
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

function Get-DevicePrefix {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SiteName,
        [Parameter(Mandatory = $true)]
        [bool]$IsLaptop
    )
    
    $siteName = $SiteName.ToUpper()
    if (-not $SITE_CONFIG.ContainsKey($siteName)) {
        throw "Unknown site: $SiteName"
    }
    
    $siteConfig = $SITE_CONFIG[$siteName]
    
    # Handle special case first
    if ($siteConfig.NamingPattern -eq 'Special') {
        return $(if ($IsLaptop) { 'JOLT-' } else { 'JOPC-' })
    }
    
    $suffix = switch ($siteConfig.NamingPattern) {
        'Full' { $(if ($IsLaptop) { 'LT-' } else { 'PC-' }) }
        'Partial' { $(if ($IsLaptop) { 'L-' } else { 'P-' }) }
        default { throw "Invalid naming pattern for site: $SiteName" }
    }
    
    return "$($siteConfig.SiteCode)$suffix"
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
        $prefix = Get-DevicePrefix -SiteName $Site -IsLaptop $IsLaptop
        $cleanSerial = $SerialNumber -replace '[^a-zA-Z0-9]', ''
        $newName = "$prefix$cleanSerial"
        
        if ($newName.Length -gt 15) {
            Write-LogEntry -Value "Name exceeded 15 characters, truncating: $newName" -Severity 2
            $newName = $newName.Substring(0, 15)
        }
        
        return $newName
    }
    catch {
        Write-LogEntry -Value "Error generating computer name: $_" -Severity 3
        throw
    }
}

function Get-SiteFromSubnet {
    try {
        # Helper function to validate IP address format
        function Test-IPAddress {
            param([string]$IP)
            [bool]($IP -as [IPAddress])
        }

        # Get all IP addresses with better filtering
        $ipAddresses = Get-NetIPAddress -AddressFamily IPv4 | 
            Where-Object { 
                $_.IPAddress -notmatch '^(169\.254\.|127\.)' -and 
                (Test-IPAddress $_.IPAddress)
            } |
            Select-Object -ExpandProperty IPAddress

        # Safely get external IP
        try {
            $externalIP = Invoke-RestMethod -Uri 'https://api.ipify.org?format=text' -ErrorAction Stop
            if (Test-IPAddress $externalIP) {
                $ipAddresses += $externalIP
                Write-LogEntry -Value "External IP found: $externalIP" -Severity 1
            }
        }
        catch {
            Write-LogEntry -Value "Could not retrieve external IP: $($_.Exception.Message)" -Severity 2
        }

        # Log all valid IPs found
        Write-LogEntry -Value "Found valid IP addresses: $($ipAddresses -join ', ')" -Severity 1

        # Check each IP against site configs
        foreach ($ip in $ipAddresses) {
            # Skip invalid IPs
            if (-not (Test-IPAddress $ip)) {
                Write-LogEntry -Value "Skipping invalid IP: $ip" -Severity 2
                continue
            }

            # First check subnet matches
            foreach ($siteName in $SITE_CONFIG.Keys) {
                $siteConfig = $SITE_CONFIG[$siteName]
                
                if (-not [string]::IsNullOrEmpty($siteConfig.SubnetPrefix) -and 
                    $siteConfig.SubnetPrefix -ne 'TBD') {
                    
                    try {
                        $subnet = $siteConfig.SubnetPrefix -split '/'
                        if ($subnet.Count -eq 2) {
                            $networkIP = [System.Net.IPAddress]::Parse($subnet[0])
                            $maskLength = [int]$subnet[1]
                            $mask = ([Math]::Pow(2, $maskLength) - 1) * [Math]::Pow(2, (32 - $maskLength))
                            $maskBytes = [BitConverter]::GetBytes([UInt32]$mask)
                            [Array]::Reverse($maskBytes)
                            $netMask = [System.Net.IPAddress]::new($maskBytes)

                            $ipAddr = [System.Net.IPAddress]::Parse($ip)
                            $networkAddr = [System.Net.IPAddress]($ipAddr.Address -band $netMask.Address)
                            $subnetAddr = [System.Net.IPAddress]($networkIP.Address -band $netMask.Address)
                            
                            if ($networkAddr.Equals($subnetAddr)) {
                                Write-LogEntry -Value "IP $ip matches subnet for site $siteName" -Severity 1
                                return $siteName
                            }
                        }
                    }
                    catch {
                        Write-LogEntry -Value "Error processing subnet for $siteName`: $($_.Exception.Message)" -Severity 2
                        continue
                    }
                }
            }

            # Then check WAN IP matches
            foreach ($siteName in $SITE_CONFIG.Keys) {
                $siteConfig = $SITE_CONFIG[$siteName]
                
                if (-not [string]::IsNullOrEmpty($siteConfig.WanIP) -and 
                    $siteConfig.WanIP -ne 'TBD') {
                    
                    # Handle multiple WAN IPs properly
                    $wanIPs = $siteConfig.WanIP -split ';' | 
                        ForEach-Object { $_.Trim() } | 
                        Where-Object { -not [string]::IsNullOrEmpty($_) }
                    
                    foreach ($wanIP in $wanIPs) {
                        $wan = $wanIP -replace '/32$', ''  # Remove /32 if present
                        if (Test-IPAddress $wan -and $ip -eq $wan) {
                            Write-LogEntry -Value "IP $ip matches WAN IP for site $siteName" -Severity 1
                            return $siteName
                        }
                    }
                }
            }
        }

        Write-LogEntry -Value "No site match found for any IP address, defaulting to REMOTE" -Severity 2
        return "REMOTE"
    }
    catch {
        Write-LogEntry -Value "Error in Get-SiteFromSubnet: $($_.Exception.Message)" -Severity 3
        Write-LogEntry -Value "Stack trace: $($_.ScriptStackTrace)" -Severity 3
        return "REMOTE"
    }
}

function Get-DeviceType {
    try {
        $systemEnclosure = Get-CimInstance -ClassName Win32_SystemEnclosure
        $chassisTypes = $systemEnclosure.ChassisTypes
        
        $laptopTypes = @(
            9, # Laptop
            10, # Notebook
            14, # Sub Notebook
            30, # Tablet
            31, # Convertible
            32  # Detachable
        )
        
        $isLaptop = $false  # Initialize the variable
        foreach ($type in $chassisTypes) {
            if ($type -in $laptopTypes) {
                $isLaptop = $true
                break
            }
        }
        
        $deviceType = if ($isLaptop) { 'Laptop' } else { 'Desktop' }
        Write-LogEntry -Value "Device detected as $deviceType (ChassisType: $($chassisTypes -join ', '))" -Severity 1
        return $isLaptop
    }
    catch {
        Write-LogEntry -Value "Error detecting device type: $($_.Exception.Message)" -Severity 3
        throw
    }
}


function Rename-ComputerBySite {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SelectedSite
    )

    try {
        if ($TestMode) {
            Write-LogEntry -Value "RUNNING IN TEST MODE - No changes will be made" -Severity 2
        }

        $currentComputerName = $env:ComputerName
        Write-LogEntry -Value "Current computer name: $currentComputerName" -Severity 1

        # Get system type
        $isLaptop = Get-DeviceType
        Write-LogEntry -Value "Device type: $(if ($isLaptop) { 'Laptop' } else { 'Desktop' })" -Severity 1

        # Get and validate serial number
        $serialNumber = Get-MachineSerialNumber
        if (-not $serialNumber) {
            Write-LogEntry -Value "Unable to get valid serial number" -Severity 3
            return $false
        }
        Write-LogEntry -Value "Retrieved serial number: $serialNumber" -Severity 1

        try {
            Write-LogEntry -Value "Attempting to generate computer name for site: $SelectedSite" -Severity 1
            $newName = Get-ComputerNameTemplate -Site $SelectedSite -SerialNumber $serialNumber -IsLaptop $isLaptop
            Write-LogEntry -Value "Successfully generated new name: $newName" -Severity 1
        }
        catch {
            Write-LogEntry -Value "Failed to generate computer name: $($_.Exception.Message)" -Severity 3
            Write-LogEntry -Value "Stack trace: $($_.ScriptStackTrace)" -Severity 3
            return $false
        }

        if ($newName -eq $currentComputerName) {
            Write-LogEntry -Value "Computer name already correct: $currentComputerName" -Severity 1
            return $true
        }

        Write-LogEntry -Value "New computer name will be: $newName" -Severity 1
        if (-not $TestMode) {
            try {
                # Use Invoke-WithRetry for the rename operation
                Invoke-WithRetry -ScriptBlock {
                    Rename-Computer -NewName $newName -Force -ErrorAction Stop
                } -OperationName "Computer Rename" -MaxAttempts 3 -DelaySeconds 5

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

#endregion

# Main execution block
try {
    # Initialize logging
    Ensure-LogDirectory

    # Log script start (only once)
    if ($TestMode) {
        Write-LogEntry -Value "Script started in TEST MODE" -Severity 2
    }
    else {
        Write-LogEntry -Value "Script started in PRODUCTION MODE" -Severity 1
    }

    # Check admin privileges
    if (-not (Test-AdminPrivileges)) {
        Write-LogEntry -Value "Script requires administrative privileges" -Severity 3
        Exit 1
    }
    Write-LogEntry -Value "Script running with administrative privileges" -Severity 1

    # Determine site
    $selectedSite = if ($Site) {
        $uppercaseSite = $Site.ToUpper()
        if (-not $SITE_CONFIG.ContainsKey($uppercaseSite)) {
            Write-LogEntry -Value "Invalid site specified: $uppercaseSite" -Severity 3
            Exit 1
        }
        Write-LogEntry -Value "Using provided site: $uppercaseSite" -Severity 1
        $uppercaseSite
    }
    else {
        Write-LogEntry -Value "No site provided, detecting from subnet..." -Severity 1
        Get-SiteFromSubnet
    }

    Write-LogEntry -Value "Selected site: $selectedSite" -Severity 1

    # Execute rename operation with selected site
    $result = Rename-ComputerBySite -SelectedSite $selectedSite
    if ($result) {
        Write-LogEntry -Value "Computer rename operation completed successfully" -Severity 1
        Restart-Computer -Force
        Exit 0
    }
    else {
        Write-LogEntry -Value "Computer rename operation failed" -Severity 3
        Exit 1
    }
}
catch {
    Write-LogEntry -Value "Unhandled error in script execution: $($_.Exception.Message)" -Severity 3
    Write-LogEntry -Value "Stack trace: $($_.ScriptStackTrace)" -Severity 3
    Exit 1
}