# Requires -RunAsAdministrator

# Define shortcut configurations
$Shortcuts = @(
    @{
        Name = "Log Off.lnk"
        Target = "$env:SystemRoot\System32\shutdown.exe"
        Arguments = "/l"
        Icon = "$env:SystemRoot\System32\SHELL32.dll,44"
        Description = "Log off current user"
    },
    @{
        Name = "Shutdown.lnk"
        Target = "$env:SystemRoot\System32\shutdown.exe"
        Arguments = "/s /t 0"
        Icon = "$env:SystemRoot\System32\SHELL32.dll,27"
        Description = "Shutdown computer"
    }
)

# Define deployment locations
$Locations = @(
    [System.Environment]::GetFolderPath('CommonDesktopDirectory'),
    (Join-Path $env:ProgramData "Microsoft\Windows\Start Menu")
)

# Function to create a shortcut
function New-SystemShortcut {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$ShortcutConfig
    )
    
    try {
        $Shell = New-Object -ComObject "WScript.Shell" -ErrorAction Stop
        $Shortcut = $Shell.CreateShortcut($Path)
        
        $Shortcut.TargetPath = $ShortcutConfig.Target
        $Shortcut.Arguments = $ShortcutConfig.Arguments
        $Shortcut.IconLocation = $ShortcutConfig.Icon
        $Shortcut.Description = $ShortcutConfig.Description
        
        $Shortcut.Save()
        
        Write-Host "Created shortcut: $Path" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to create shortcut at $Path : $_"
        return $false
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

# Main deployment logic
try {
    # Check for admin rights
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        throw "This script requires administrator privileges. Please run as administrator."
    }
    
    # Process each location
    foreach ($Location in $Locations) {
        Write-Host "`nDeploying shortcuts to: $Location" -ForegroundColor Cyan
        
        # Ensure the directory exists
        if (-not (Test-Path -Path $Location -PathType Container)) {
            New-Item -Path $Location -ItemType Directory -Force | Out-Null
        }
        
        # Create each shortcut
        foreach ($Shortcut in $Shortcuts) {
            $ShortcutPath = Join-Path -Path $Location -ChildPath $Shortcut.Name
            
            # Check if shortcut already exists
            if (Test-Path -Path $ShortcutPath -PathType Leaf) {
                Write-Host "Shortcut already exists: $ShortcutPath" -ForegroundColor Yellow
                
                # Optional: Uncomment to force update existing shortcuts
                # Remove-Item -Path $ShortcutPath -Force
                # New-SystemShortcut -Path $ShortcutPath -ShortcutConfig $Shortcut
            }
            else {
                New-SystemShortcut -Path $ShortcutPath -ShortcutConfig $Shortcut
            }
        }
    }
    
    Write-Host "`nDeployment completed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "Deployment failed: $_"
}
finally {
    # Final cleanup
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}