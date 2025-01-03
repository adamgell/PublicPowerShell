function New-IntuneDriverGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [IntuneDevice]$DeviceInfo,

        [Parameter(Mandatory = $false)]
        [hashtable]$Settings = $script:defaultSettings
    )

    try {
        $groupName = "$($Settings.NamePrefix)$($DeviceInfo.Manufacturer) $($DeviceInfo.FriendlyName)$($Settings.NameSuffix)"
        
        if ($DeviceInfo.FriendlyName.StartsWith($DeviceInfo.Manufacturer)) {
            $groupName = "$($Settings.NamePrefix)$($DeviceInfo.FriendlyName)$($Settings.NameSuffix)"
        }

        # Check if group exists
        $existingGroup = Get-MgGroup -Filter "DisplayName eq '$groupName'"
        if ($existingGroup) {
            Write-Verbose "Group already exists: $groupName"
            return $existingGroup
        }

        $membershipRule = '(device.deviceModel -eq "' + $($DeviceInfo.OriginalModel) + 
                         '") and (device.deviceManufacturer -eq "' + $($DeviceInfo.Manufacturer) + '")'

        $groupParams = @{
            DisplayName = $groupName
            Description = "Dynamic group for $($DeviceInfo.FriendlyName) driver updates"
            GroupTypes = @('DynamicMembership')
            SecurityEnabled = $true
            IsAssignableToRole = $false
            MailEnabled = $false
            MailNickname = (New-Guid).Guid.Substring(0,10)
            MembershipRule = $membershipRule
            MembershipRuleProcessingState = "On"
            "Owners@odata.bind" = @("https://graph.microsoft.com/v1.0/me")
        }

        $group = New-MgGroup -BodyParameter $groupParams
        Write-Verbose "Created new group: $groupName"
        return $group
    }
    catch {
        Write-Error "Failed to create group: $_"
        return $null
    }
}