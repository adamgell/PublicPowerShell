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
    [Parameter(Mandatory = $true)]
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
        SubnetPrefix  = ''
        WanIP         = ''
        TimeZone      = 'Eastern Standard Time'
        NamingPattern = 'Full'
        SiteCode      = 'AL'
    }
    'ANTIBES'      = @{
        SubnetPrefix  = ''
        WanIP         = ''
        TimeZone      = 'Central European Standard Time'
        NamingPattern = 'Partial'
        SiteCode      = 'ANT'
    }
    'BATAM'        = @{
        SubnetPrefix  = ''
        WanIP         = ''
        TimeZone      = 'Western Indonesian Time'
        NamingPattern = 'Partial'
        SiteCode      = 'BAT'
    }
    'BINGHAMTON'   = @{
        SubnetPrefix  = ''
        WanIP         = ''
        TimeZone      = 'Eastern Standard Time'
        NamingPattern = 'Full'
        SiteCode      = 'BI'
    }
    'BURLINGTON'   = @{
        SubnetPrefix  = ''
        WanIP         = ''
        TimeZone      = 'Eastern Standard Time'
        NamingPattern = 'Full'
        SiteCode      = 'BU'
    }
    'CASARZA'      = @{
        SubnetPrefix  = ''
        WanIP         = ''
        TimeZone      = 'Central European Standard Time'
        NamingPattern = 'Partial'
        SiteCode      = 'CAS'
    }
    'DURBAN'       = @{
        SubnetPrefix  = ''
        WanIP         = ''
        TimeZone      = 'South Africa Standard Time'
        NamingPattern = 'Partial'
        SiteCode      = 'DUR'
    }
    'EL_CAJON'     = @{
        SubnetPrefix  = ''
        WanIP         = ''
        TimeZone      = 'Pacific Standard Time'
        NamingPattern = 'Full'
        SiteCode      = 'EC'
    }
    'EUFAULA'      = @{
        SubnetPrefix  = ''
        WanIP         = ''
        TimeZone      = 'Central Standard Time'
        NamingPattern = 'Full'
        SiteCode      = 'EU'
    }
    'LITTLE_FALLS' = @{
        SubnetPrefix  = ''
        WanIP         = ''
        TimeZone      = 'Central Standard Time'
        NamingPattern = 'Full'
        SiteCode      = 'LF'
    }
    'MANKATO'      = @{
        SubnetPrefix  = ''
        WanIP         = ''
        TimeZone      = 'Central Standard Time'
        NamingPattern = 'Full'
        SiteCode      = 'MA'
    }
    'MEXICALI'     = @{
        SubnetPrefix  = ''
        WanIP         = ''
        TimeZone      = 'Pacific Standard Time'
        NamingPattern = 'Full'
        SiteCode      = 'ME'
    }
    'NUREMBERG'    = @{
        SubnetPrefix  = ''
        WanIP         = ''
        TimeZone      = 'Central European Standard Time'
        NamingPattern = 'Partial'
        SiteCode      = 'NUR'
    }
    'OLD_TOWN'     = @{
        SubnetPrefix  = ''
        WanIP         = ''
        TimeZone      = 'Eastern Standard Time'
        NamingPattern = 'Full'
        SiteCode      = 'OT'
    }
    'RACINE'       = @{
        SubnetPrefix  = ''
        WanIP         = ''
        TimeZone      = 'Central Standard Time'
        NamingPattern = 'Full'
        SiteCode      = 'RA'
    }
    'TORONTO'      = @{
        SubnetPrefix  = ''
        WanIP         = ''
        TimeZone      = 'Eastern Standard Time'
        NamingPattern = 'Full'
        SiteCode      = 'TO'
    }
    'SPREITENBACH' = @{
        SubnetPrefix  = ''
        WanIP         = ''
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
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-LogEntry -Value "Script requires administrative privileges" -Severity 3
        return $false
    }
    Write-LogEntry -Value "Script running with administrative privileges" -Severity 1
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
            #Write-LogEntry -Value "Non-unique serial number detected, generating random serial" -Severity 2
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
    
    # Validate site exists in config
    $siteName = $SiteName.ToUpper()
    if (-not $SITE_CONFIG.ContainsKey($siteName)) {
        throw "Unknown site: $SiteName"
    }
    
    $siteConfig = $SITE_CONFIG[$siteName]
    $siteCode = $SITE_CONFIG[$siteName].SiteCode
    
    
    
    # Handle special case first
    if ($siteConfig.NamingPattern -eq 'Special') {
        return $(if ($IsLaptop) { 'JOLT-' } else { 'JOPC-' })
    }
    
    # Build prefix based on pattern
    $suffix = switch ($siteConfig.NamingPattern) {
        'Full' { $(if ($IsLaptop) { 'LT-' } else { 'PC-' }) }
        'Partial' { $(if ($IsLaptop) { 'L-' } else { 'P-' }) }
        default { throw "Invalid naming pattern for site: $SiteName" }
    }
    
    return "$siteCode$suffix"
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
#endregion

# Replace the existing laptop detection with:
function Get-DeviceType {
    try {
        $systemEnclosure = Get-CimInstance -ClassName Win32_SystemEnclosure
        $chassisTypes = $systemEnclosure.ChassisTypes
        
        $laptopTypes = @(
            9,  # Laptop
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
        
        Write-LogEntry -Value "Device detected as $($isLaptop ? 'Laptop' : 'Desktop') (ChassisType: $($chassisTypes -join ', '))" -Severity 1
        return $isLaptop
    }
    catch {
        Write-LogEntry -Value "Error detecting device type: $($_.Exception.Message)" -Severity 3
        throw
    }
}

#region Main Functions
function Rename-ComputerBySite {
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

        # Inside Rename-ComputerBySite, update the name generation section:
        try {
            Write-LogEntry -Value "Attempting to generate computer name for site: $Site" -Severity 1
            $newName = Get-ComputerNameTemplate -Site $Site -SerialNumber $serialNumber -IsLaptop ($null -ne $isLaptop)
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

# Main execution
if ($TestMode) {
    Write-LogEntry -Value "Script started in TEST MODE" -Severity 2
}
else {
    Write-LogEntry -Value "Script started in PRODUCTION MODE" -Severity 1
}

$siteName = foreach ($site in ($SITE_CONFIG).Keys) {
    $site
}

$siteName = $siteName | Sort-Object

function Test-AllNamingPatterns {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Sites
    )
    
    foreach ($deviceType in @('Desktop', 'Laptop')) {
        $banner = @"
    ===========================================
    RENAME COMPUTER BY SITE - $deviceType
    ===========================================
"@ 
        Write-LogEntry -Value $banner -Severity 1
        
        foreach ($site in $Sites) {
            Write-LogEntry -Value "Site: $site" -Severity 1
            $serialNumber = Get-MachineSerialNumber
            $isLaptop = $deviceType -eq 'Laptop'
            
            try {
                $result = Get-ComputerNameTemplate -Site $site -SerialNumber $serialNumber -IsLaptop $isLaptop
                Write-LogEntry -Value $result -Severity 1 -textcolor "white"
            }
            catch {
                Write-LogEntry -Value "Failed to generate name for $site ($deviceType): $($_.Exception.Message)" -Severity 3
            }
        }
    }
}

Test-AllNamingPatterns -Sites $siteName

