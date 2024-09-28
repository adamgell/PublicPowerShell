# Required modules
$requiredModules = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Beta.DeviceManagement",
    "Microsoft.Graph.Beta.Groups",
    "Microsoft.Graph.Beta.Identity.DirectoryManagement"
)

# Required permissions
$requiredPermissions = @(
    "DeviceManagementConfiguration.ReadWrite.All",
    "DeviceManagementManagedDevices.ReadWrite.All",
    "Directory.ReadWrite.All",
    "Group.ReadWrite.All",
    "GroupMember.ReadWrite.All",
    "Device.ReadWrite.All"
)

function Install-RequiredModules {
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Host "Installing required module: $module"
            Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
        }
    }
}

function Connect-MgGraphWithPermissions {
    Connect-MgGraph -Scopes $requiredPermissions -NoWelcome
    $currentPermissions = (Get-MgContext).Scopes
    $missingPermissions = $requiredPermissions | Where-Object { $_ -notin $currentPermissions }
    
    if ($missingPermissions) {
        Write-Warning "The following required permissions are missing: $($missingPermissions -join ', ')"
        Write-Warning "Please grant these permissions and run the script again."
        exit
    }
}


function Get-LevenshteinDistance {
    param (
        [string]$Source,
        [string]$Target
    )

    $n = $Source.Length
    $m = $Target.Length
    $d = New-Object 'int[,]' ($n + 1), ($m + 1)

    if ($n -eq 0) { return $m }
    if ($m -eq 0) { return $n }

    for ($i = 0; $i -le $n; $i++) { $d[$i, 0] = $i }
    for ($j = 0; $j -le $m; $j++) { $d[0, $j] = $j }

    for ($i = 1; $i -le $n; $i++) {
        for ($j = 1; $j -le $m; $j++) {
            $cost = if ($Target[$j - 1] -eq $Source[$i - 1]) { 0 } else { 1 }
            $d[$i, $j] = [Math]::Min(
                [Math]::Min($d[($i - 1), $j] + 1, $d[$i, ($j - 1)] + 1),
                $d[($i - 1), ($j - 1)] + $cost
            )
        }
    }

    return $d[$n, $m]
}

function Get-StringSimilarity {
    param (
        [string]$Source,
        [string]$Target
    )

    $maxLength = [Math]::Max($Source.Length, $Target.Length)
    if ($maxLength -eq 0) { return 100 }

    $distance = Get-LevenshteinDistance -Source $Source -Target $Target
    return (1 - $distance / $maxLength) * 100
}

function Get-FuzzyMatch {
    param (
        [string]$Pattern,
        [string[]]$StringArray,
        [int]$Threshold = 80
    )

    $bestMatch = $null
    $highestSimilarity = 0

    foreach ($string in $StringArray) {
        $similarity = Get-StringSimilarity -Source $Pattern -Target $string
        if ($similarity -gt $highestSimilarity -and $similarity -ge $Threshold) {
            $highestSimilarity = $similarity
            $bestMatch = $string
        }
    }

    return @{
        Match      = $bestMatch
        Similarity = $highestSimilarity
    }
}


function Find-AzureADDevice {
    param (
        [Parameter(Mandatory = $true)]
        $IntuneDevice,
        [Parameter(Mandatory = $true)]
        [array]$AllDevices
    )

    $azureADDevice = $null

    # Try matching by Intune Device ID
    if (-not [string]::IsNullOrWhiteSpace($IntuneDevice.Id)) {
        $azureADDevice = $AllDevices | Where-Object { $_.DeviceId -eq $IntuneDevice.Id } | Select-Object -First 1
    }

    # If not found, try matching by device name
    if (-not $azureADDevice -and -not [string]::IsNullOrWhiteSpace($IntuneDevice.DeviceName)) {
        $azureADDevice = $AllDevices | Where-Object { $_.DisplayName -eq $IntuneDevice.DeviceName } | Select-Object -First 1
    }

    # If still not found, try partial matching
    if (-not $azureADDevice -and -not [string]::IsNullOrWhiteSpace($IntuneDevice.DeviceName)) {
        $azureADDevice = $AllDevices | Where-Object { 
            $_.DisplayName -like "*$($IntuneDevice.DeviceName)*" -or
            $IntuneDevice.DeviceName -like "*$($_.DisplayName)*"
        } | Select-Object -First 1
    }

    return $azureADDevice
}
function Invoke-MultipleAppInstalledDevicesGroups {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$AppDisplayNames,
        [Parameter(Mandatory = $false)]
        [int]$CacheExpirationMinutes = 60,
        [Parameter(Mandatory = $false)]
        [int]$FuzzyMatchThreshold = 80
    )

    # Initialize cache
    $script:cache = @{}
    $script:cacheTimestamp = Get-Date

    # Initialize summary report
    $summaryReport = @{}

    function Get-CachedData {
        param (
            [string]$Key
        )
        if ($script:cache.ContainsKey($Key) -and ((Get-Date) - $script:cacheTimestamp).TotalMinutes -lt $CacheExpirationMinutes) {
            return $script:cache[$Key]
        }
        return $null
    }

    function Set-CachedData {
        param (
            [string]$Key,
            $Value
        )
        $script:cache[$Key] = $Value
        $script:cacheTimestamp = Get-Date
    }

    function Get-AllDevices {
        $cachedDevices = Get-CachedData -Key "AllDevices"
        if ($null -eq $cachedDevices) {
            Write-Host "Fetching all devices..."
            $cachedDevices = Get-MgBetaDevice -All
            Set-CachedData -Key "AllDevices" -Value $cachedDevices
        }
        return $cachedDevices
    }

    function Get-AllDetectedApps {
        $cachedApps = Get-CachedData -Key "AllDetectedApps"
        if ($null -eq $cachedApps) {
            Write-Host "Fetching all detected apps..."
            $cachedApps = Get-MgBetaDeviceManagementDetectedApp -All
            Set-CachedData -Key "AllDetectedApps" -Value $cachedApps
        }
        return $cachedApps
    }    

    try {
        $allDevices = Get-AllDevices
        Write-Host "Total devices fetched: $($allDevices.Count)"
        
        $allDetectedApps = Get-AllDetectedApps
        Write-Host "Total detected apps fetched: $($allDetectedApps.Count)"

        foreach ($AppDisplayName in $AppDisplayNames) {
            Write-Host "Processing application: $AppDisplayName"

            # Find the best match for the app name
            $allAppNames = $allDetectedApps | Select-Object -ExpandProperty DisplayName -Unique
            $matchResult = Get-FuzzyMatch -Pattern $AppDisplayName -StringArray $allAppNames -Threshold $FuzzyMatchThreshold

            if ($matchResult.Match) {
                $bestMatch = $matchResult.Match
                Write-Host "Best match found: $bestMatch (Similarity: $($matchResult.Similarity.ToString("0.00"))%)"
                
                # Get devices with the app installed
                $DetectedInstalls = $allDetectedApps | Where-Object { $_.DisplayName -eq $bestMatch }
                $DetectedInstallDevices = @()
                foreach ($install in $DetectedInstalls) {
                    $appDevices = Get-MgBetaDeviceManagementDetectedAppManagedDevice -DetectedAppId $install.Id
                    $DetectedInstallDevices += $appDevices
                }
                # Removed: $DetectedInstallDevices = $DetectedInstallDevices | Select-Object -Unique
                Write-Host "Total devices with app installed: $($DetectedInstallDevices.Count)"
                Write-Host "Total unique devices with app installed: $($DetectedInstallDevices.Count)"

                # Define and get/create the group
                $GroupName = "$($bestMatch -replace '[^a-zA-Z0-9]', '')_Installed_Devices"
                $Group = Get-MgBetaGroup -Filter "displayName eq '$GroupName'" | Select-Object -First 1
                if (-not $Group) {
                    # Create group if it doesn't exist
                    $GroupParams = @{
                        DisplayName     = $GroupName
                        Description     = "Devices with [$bestMatch] installed"
                        MailEnabled     = $false
                        MailNickname    = $GroupName
                        SecurityEnabled = $true
                        GroupTypes      = @()
                    }
                    $Group = New-MgBetaGroup @GroupParams
                    Write-Host "Device Group '$GroupName' created."
                }

                $currentGroupMembers = Get-MgBetaGroupMember -GroupId $Group.Id -All
                Write-Host "Current group members: $($currentGroupMembers.Count)"

                $devicesAdded = 0
                $devicesRemoved = 0

                <# Add new devices to the group
                foreach ($device in $DetectedInstallDevices) {
                    $azureADDevice = Find-AzureADDevice -IntuneDevice $device -AllDevices $allDevices
                    if ($azureADDevice -and $azureADDevice.Id -notin $currentGroupMembers.Id) {
                        try {
                            New-MgBetaGroupMember -GroupId $Group.Id -DirectoryObjectId $azureADDevice.Id -ErrorAction Stop
                            Write-Host "Added $($azureADDevice.DisplayName) to group '$GroupName'."
                            $devicesAdded++
                        }
                        catch {
                            Write-Warning "Failed to add $($azureADDevice.DisplayName) to group '$GroupName': $($_.Exception.Message)"
                        }
                    }
                }#>

                # Add new devices to the group
                foreach ($device in $DetectedInstallDevices) {
                    $azureADDevice = Find-AzureADDevice -IntuneDevice $device -AllDevices $allDevices
                    if ($azureADDevice) {
                        if ($azureADDevice.Id -notin $currentGroupMembers.Id) {
                            try {
                                New-MgBetaGroupMember -GroupId $Group.Id -DirectoryObjectId $azureADDevice.Id -ErrorAction Stop
                                Write-Host "Added $($azureADDevice.DisplayName) (Intune ID: $($device.Id), Azure AD ID: $($azureADDevice.Id)) to group '$GroupName'."
                                $devicesAdded++
                            }
                            catch {
                                Write-Warning "Failed to add $($azureADDevice.DisplayName) to group '$GroupName': $($_.Exception.Message)"
                            }
                        }
                        else {
                            Write-Host "$($azureADDevice.DisplayName) is already a member of group '$GroupName'."
                        }
                    }
                    else {
                        Write-Warning "Could not find Azure AD device for Intune device: $($device.DeviceName) (ID: $($device.Id))"
                    }
                }

                # Remove devices no longer having the app
                foreach ($member in $currentGroupMembers) {
                    $shouldRemove = $true
                    foreach ($device in $DetectedInstallDevices) {
                        $azureADDevice = Find-AzureADDevice -IntuneDevice $device -AllDevices $allDevices
                        if ($azureADDevice -and $azureADDevice.Id -eq $member.Id) {
                            $shouldRemove = $false
                            break
                        }

                    }
                    if ($shouldRemove) {
                        try {
                            Remove-MgBetaGroupMemberByRef -GroupId $Group.Id -DirectoryObjectId $member.Id -ErrorAction Stop
                            Write-Host "Removed $($member.DisplayName) from group '$GroupName'."
                            $devicesRemoved++
                        }
                        catch {
                            Write-Warning "Failed to remove $($member.DisplayName) from group '$GroupName': $($_.Exception.Message)"
                        }
                    }
                }

                # Get final group members
                $finalGroupMembers = Get-MgBetaGroupMember -GroupId $Group.Id -All
                
                # Update summary report
                $summaryReport[$bestMatch] = @{
                    OriginalName    = $AppDisplayName
                    TotalDevices    = $DetectedInstallDevices.Count
                    DevicesAdded    = $devicesAdded
                    DevicesRemoved  = $devicesRemoved
                    FinalGroupCount = $finalGroupMembers.Count
                }

                Write-Host "Final group membership for $GroupName :"
                $finalGroupMembers | ForEach-Object {
                    Write-Host "  - $($_.DisplayName) (ID: $($_.Id))"
                }
            }
            else {
                Write-Host "No matching app found for '$AppDisplayName' in your tenant."
            }
        }

        # Display summary report
        Write-Host "`nSummary Report:"
        Write-Host "---------------"
        foreach ($app in $summaryReport.Keys) {
            Write-Host "Application: $app"
            Write-Host "  Original Search Term: $($summaryReport[$app].OriginalName)"
            Write-Host "  Total Devices with app installed: $($summaryReport[$app].TotalDevices)"
            Write-Host "  Devices added to group: $($summaryReport[$app].DevicesAdded)"
            Write-Host "  Devices removed from group: $($summaryReport[$app].DevicesRemoved)"
            Write-Host "  Final group member count: $($summaryReport[$app].FinalGroupCount)"
            Write-Host ""
        }
    }
    catch {
        Write-Warning "An error occurred: $($_.Exception.Message)"
        Write-Warning "Stack Trace: $($_.ScriptStackTrace)"
    }
}

# Main execution
Install-RequiredModules
Connect-MgGraphWithPermissions

# Example usage
$AppsToTrack = @("Google Chrome", "Microsoft Edge", "Mozilla Firefox (x64 en-US)", "Citrix Workspace 2405", "WinZip 28.0")
Invoke-MultipleAppInstalledDevicesGroups -AppDisplayNames $AppsToTrack -FuzzyMatchThreshold 80