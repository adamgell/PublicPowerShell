# Script: Windows Firewall Rule Analysis with Port Information
# Purpose: Analyzes Windows Firewall rules, matching them with port configurations and application filters
# Outputs: Table of firewall rules with associated ports, protocols, and application information

# Error handling preference
$ErrorActionPreference = 'Stop'

try {
    Write-Verbose "Retrieving all firewall rules..."
    # Cache all firewall rules for performance optimization
    # This is faster than retrieving rules individually later
    $allRules = Get-NetFirewallRule
    if (-not $allRules) {
        throw "Failed to retrieve firewall rules. Ensure you have administrative privileges."
    }

    Write-Verbose "Retrieving application filters..."
    # Get application filters which contain program/process information
    $allAppFilters = Get-NetFirewallApplicationFilter
    if (-not $allAppFilters) {
        Write-Warning "No application filters found. Program information may be limited."
    }

    Write-Verbose "Processing port filters and matching with rules..."
    # Main analysis: Get port filters and create detailed report
    Get-NetFirewallPortFilter | 
        Group-Object LocalPort, Protocol | 
        Select-Object @{
            Name = 'Local Port'
            Expression = {
                # Try converting port to integer for proper sorting
                # Keep as string if not a valid integer (e.g., "Any")
                try {
                    $port = $_.Group[0].LocalPort
                    if ($p = $port -as [int]) { 
                        $p 
                    } else { 
                        $port
                    }
                } catch {
                    Write-Warning "Error processing local port: $_"
                    "Error"
                }
            }
        },
        @{
            Name = 'Remote Port'
            Expression = {
                # Similar conversion for remote ports
                try {
                    $port = $_.Group[0].RemotePort
                    if ($p = $port -as [int]) { 
                        $p 
                    } else { 
                        $port
                    }
                } catch {
                    Write-Warning "Error processing remote port: $_"
                    "Error"
                }
            }
        },
        @{
            Name = 'Protocol'
            Expression = { 
                try {
                    $_.Group[0].Protocol
                } catch {
                    Write-Warning "Error retrieving protocol: $_"
                    "Unknown"
                }
            }
        },
        @{
            Name = 'Enabled'
            Expression = { 
                try {
                    # Get the current group of rules
                    $group = $_.Group
                    # Find matching rules that are enabled
                    $script:rules = $allRules | Where-Object { 
                        $group.InstanceID -contains $_.Name -and 
                        $_.Enabled -ieq 'true'
                    }
                    $script:rules | Select-Object -ExpandProperty Enabled -Unique
                } catch {
                    Write-Warning "Error checking enabled status: $_"
                    $false
                }
            }
        },
        @{
            Name = 'Program'
            Expression = {
                try {
                    $group = $_.Group
                    # Match application filters with current rules
                    $script:appRule = $allAppFilters | Where-Object { 
                        $group.InstanceId -contains $_.InstanceId
                    }
                    # Get unique program paths
                    $programs = $script:appRule.Program | Select-Object -Unique
                    if ($programs) {
                        $programs
                    } else {
                        "Any Program"  # Default when no specific program is specified
                    }
                } catch {
                    Write-Warning "Error retrieving program information: $_"
                    "Error"
                }
            }
        },
        @{
            Name = 'Direction'
            Expression = {
                try {
                    $script:rules | Select-Object -ExpandProperty Direction -Unique
                } catch {
                    Write-Warning "Error retrieving direction: $_"
                    "Unknown"
                }
            }
        },
        @{
            Name = 'Action'
            Expression = {
                try {
                    $script:rules | Select-Object -ExpandProperty Action -Unique
                } catch {
                    Write-Warning "Error retrieving action: $_"
                    "Unknown"
                }
            }
        },
        @{
            Name = 'Rules'
            Expression = {
                try {
                    # Join all rule names with newlines for readability
                    ($script:rules | 
                        Select-Object -ExpandProperty DisplayName -Unique | 
                        Sort-Object) -join "`n"
                } catch {
                    Write-Warning "Error retrieving rule names: $_"
                    "Error retrieving rules"
                }
            }
        } |
        # Filter to show only enabled rules
        Where-Object { $_.Enabled } |
        # Sort by local port for better organization
        Sort-Object 'Local Port' | Format-Table

} catch {
    Write-Error "Critical error in firewall analysis: $_"
    throw  # Re-throw the error for proper handling by calling script
} finally {
    # Clean up variables to free memory
    Remove-Variable -Name allRules, allAppFilters, rules, appRule -ErrorAction SilentlyContinue
}