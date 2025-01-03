function Connect-IntuneDriverManagement {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string[]]$RequiredScopes = @(
            "DeviceManagementManagedDevices.ReadWrite.All",
            "Group.ReadWrite.All",
            "DeviceManagementConfiguration.ReadWrite.All",
            "GroupMember.ReadWrite.All"
        )
    )

    try {
        $context = Get-MgContext
        if (-not $context) {
            Connect-MgGraph -Scopes $RequiredScopes
            $context = Get-MgContext
        }

        if (-not $context) {
            throw "Failed to establish Graph connection"
        }

        return $true
    }
    catch {
        Write-Error "Failed to initialize connection: $_"
        return $false
    }
}