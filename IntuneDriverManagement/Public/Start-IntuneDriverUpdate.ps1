
function Start-IntuneDriverUpdate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [hashtable]$Settings = $script:defaultSettings
    )

    try {
        # Ensure we're connected
        if (-not (Connect-IntuneDriverManagement)) {
            throw "Failed to establish required connection"
        }

        # Get all Windows devices
        $intuneDevices = Get-MgDeviceManagementManagedDevice -Filter "OperatingSystem eq 'Windows'" | 
                        Sort-Object -Property Model -Unique

        $results = @()
        foreach ($device in $intuneDevices) {
            if ($device.Model -notin $Settings.ExcludedModels) {
                Write-Verbose "Processing device: $($device.Manufacturer) $($device.Model)"
                
                # Process each step and collect results
                $result = @{
                    Device = $device
                    DeviceInfo = Get-IntuneDeviceInfo -Manufacturer $device.Manufacturer -Model $device.Model
                    Group = $null
                    Profile = $null
                    Assignment = $null
                    Success = $false
                    Error = $null
                }

                try {
                    $result.Group = New-IntuneDriverGroup -DeviceInfo $result.DeviceInfo -Settings $Settings
                    if ($result.Group) {
                        $result.Profile = New-IntuneDriverProfile -GroupName $result.Group.DisplayName
                        if ($result.Profile) {
                            $result.Assignment = New-IntuneDriverProfileAssignment -ProfileId $result.Profile.id -GroupId $result.Group.id
                            $result.Success = $true
                        }
                    }
                }
                catch {
                    $result.Error = $_.Exception.Message
                }

                $results += [PSCustomObject]$result
            }
        }

        return $results
    }
    catch {
        Write-Error "Failed to process driver updates: $_"
        return $null
    }
}
