function Get-IntuneDeviceInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Manufacturer,

        [Parameter(Mandatory = $true)]
        [string]$Model
    )

    try {
        # Create a new device info object
        $deviceInfo = [IntuneDevice]::new($Manufacturer, $Model)

        # Normalize manufacturer name
        $deviceInfo.Manufacturer = switch -Wildcard ($deviceInfo.Manufacturer) {
            "*Microsoft*" { "Microsoft" }
            "*HP*" { "HP" }
            "*Hewlett-Packard*" { "HP" }
            "*Dell*" { "Dell" }
            "*Lenovo*" { "Lenovo" }
            default { $deviceInfo.Manufacturer.Trim() }
        }

        return $deviceInfo
    }
    catch {
        Write-Error "Failed to process device information: $_"
        return $null
    }
}