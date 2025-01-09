# Detection script for system shortcuts
# Returns 0 if all shortcuts are present, 1 if any are missing

# Define the shortcuts we're looking for
$RequiredShortcuts = @(
    @{
        Name = "Log Off.lnk"
        Target = "$env:SystemRoot\System32\shutdown.exe"
        ExpectedArguments = "/l"
    },
    @{
        Name = "Shutdown.lnk"
        Target = "$env:SystemRoot\System32\shutdown.exe"
        ExpectedArguments = "/s /t 0"
    }
)

# Define locations to check
$Locations = @(
    @{
        Path = [System.Environment]::GetFolderPath('CommonDesktopDirectory')
        Description = "Public Desktop"
    },
    @{
        Path = (Join-Path $env:ProgramData "Microsoft\Windows\Start Menu")
        Description = "Common Start Menu"
    }
)

# Function to verify shortcut properties
function Test-ShortcutProperties {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [string]$ExpectedTarget,
        
        [Parameter(Mandatory=$true)]
        [string]$ExpectedArguments
    )
    
    try {
        $Shell = New-Object -ComObject "WScript.Shell"
        $Shortcut = $Shell.CreateShortcut($Path)
        
        $isValid = $true
        $issues = @()

        # Check target path
        if ($Shortcut.TargetPath -ne $ExpectedTarget) {
            $isValid = $false
            $issues += "Invalid target path: Expected '$ExpectedTarget', found '$($Shortcut.TargetPath)'"
        }

        # Check arguments
        if ($Shortcut.Arguments -ne $ExpectedArguments) {
            $isValid = $false
            $issues += "Invalid arguments: Expected '$ExpectedArguments', found '$($Shortcut.Arguments)'"
        }

        return @{
            IsValid = $isValid
            Issues = $issues
        }
    }
    catch {
        return @{
            IsValid = $false
            Issues = @("Failed to read shortcut properties: $_")
        }
    }
    finally {
        if ($Shortcut) {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Shortcut) | Out-Null
        }
        if ($Shell) {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Shell) | Out-Null
        }
    }
}

# Initialize results
$AllPresent = $true
$Results = @()

# Check each location
foreach ($Location in $Locations) {
    Write-Host "`nChecking shortcuts in $($Location.Description) ($($Location.Path)):" -ForegroundColor Cyan
    
    # Check if the location exists
    if (-not (Test-Path -Path $Location.Path -PathType Container)) {
        Write-Host "Location does not exist!" -ForegroundColor Red
        $AllPresent = $false
        continue
    }
    
    # Check each required shortcut
    foreach ($Shortcut in $RequiredShortcuts) {
        $ShortcutPath = Join-Path -Path $Location.Path -ChildPath $Shortcut.Name
        $Status = @{
            Location = $Location.Description
            Shortcut = $Shortcut.Name
            Present = Test-Path -Path $ShortcutPath -PathType Leaf
            Path = $ShortcutPath
        }
        
        if ($Status.Present) {
            $Verification = Test-ShortcutProperties -Path $ShortcutPath -ExpectedTarget $Shortcut.Target -ExpectedArguments $Shortcut.ExpectedArguments
            $Status.Valid = $Verification.IsValid
            $Status.Issues = $Verification.Issues
            
            if ($Verification.IsValid) {
                Write-Host "✓ Found valid shortcut: $($Shortcut.Name)" -ForegroundColor Green
            }
            else {
                Write-Host "⚠ Found invalid shortcut: $($Shortcut.Name)" -ForegroundColor Yellow
                Write-Host "  Issues:" -ForegroundColor Yellow
                foreach ($Issue in $Verification.Issues) {
                    Write-Host "   - $Issue" -ForegroundColor Yellow
                }
                $AllPresent = $false
            }
        }
        else {
            Write-Host "✗ Missing shortcut: $($Shortcut.Name)" -ForegroundColor Red
            $AllPresent = $false
        }
        
        $Results += [PSCustomObject]$Status
    }
}

# Output detailed results
Write-Host "`nDetailed Results:" -ForegroundColor Cyan
$Results | Format-Table -AutoSize

# Final status
Write-Host "`nFinal Status:" -ForegroundColor Cyan
if ($AllPresent) {
    Write-Host "All shortcuts are present and valid." -ForegroundColor Green
    exit 0
}
else {
    Write-Host "Some shortcuts are missing or invalid." -ForegroundColor Red
    exit 1
}