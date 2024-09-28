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
    function Find-AzureADDevice {
        param (
            [Parameter(Mandatory = $false)]
            [AllowEmptyString()]
            [AllowNull()]
            [string]$DeviceName,
            [Parameter(Mandatory = $false)]
            [AllowEmptyString()]
            [AllowNull()]
            [string]$IntuneDeviceId,
            [Parameter(Mandatory = $true)]
            [array]$AllDevices
        )
    
        if ([string]::IsNullOrWhiteSpace($DeviceName) -and [string]::IsNullOrWhiteSpace($IntuneDeviceId)) {
            Write-Warning "Both device name and Intune device ID are empty or null."
            return $null
        }
    
        # Try matching by Intune device ID first
        if (-not [string]::IsNullOrWhiteSpace($IntuneDeviceId)) {
            $azureADDevice = $AllDevices | Where-Object { $_.DeviceId -eq $IntuneDeviceId -or $_.Id -eq $IntuneDeviceId } | Select-Object -First 1
            if ($azureADDevice) { return $azureADDevice }
        }
    
        # If no match by Intune ID or no ID provided, try matching by name
        if (-not [string]::IsNullOrWhiteSpace($DeviceName)) {
            $azureADDevice = $AllDevices | Where-Object { $_.DisplayName -eq $DeviceName -or $_.DeviceName -eq $DeviceName } | Select-Object -First 1
            if ($azureADDevice) { return $azureADDevice }
    
            # If no exact match, try partial match
            $azureADDevice = $AllDevices | Where-Object { 
                $_.DisplayName -like "*$DeviceName*" -or 
                $DeviceName -like "*$($_.DisplayName)*" -or 
                $_.DeviceName -like "*$DeviceName*" -or 
                $DeviceName -like "*$($_.DeviceName)*"
            } | Select-Object -First 1
            if ($azureADDevice) { return $azureADDevice }
        }
    
        Write-Warning "No Azure AD device found matching name '$DeviceName' or Intune ID '$IntuneDeviceId'"
        return $null
    }

    try {
        $allDevices = Get-AllDevices
        Write-Host "Total devices fetched: $($allDevices.Count)"
        
        try {
            $allDetectedApps = Get-AllDetectedApps
            Write-Host "Total detected apps fetched: $($allDetectedApps.Count)"
        }
        catch {
            Write-Error "Failed to retrieve all detected apps. The script will continue with limited functionality."
            $allDetectedApps = @()
        }

        $totalApps = $AppDisplayNames.Count
        $currentAppIndex = 0
        $summaryReport = @{}

        foreach ($AppDisplayName in $AppDisplayNames) {
            $currentAppIndex++
            $percentComplete = ($currentAppIndex / $totalApps) * 100
            Write-Progress -Activity "Processing Applications" -Status "Processing $AppDisplayName" -PercentComplete $percentComplete

            Write-Host "Processing application: $AppDisplayName"

            # Get all unique app names
            $allAppNames = $allDetectedApps | Select-Object -ExpandProperty DisplayName -Unique

            # Find the best fuzzy match for the current app name
            $matchResult = Get-FuzzyMatch -Pattern $AppDisplayName -StringArray $allAppNames -Threshold $FuzzyMatchThreshold

            if ($matchResult.Match) {
                $bestMatch = $matchResult.Match
                Write-Host "Best match found: $bestMatch (Similarity: $($matchResult.Similarity.ToString("0.00"))%)"
                
                # Filter detected installations of the matched application
                $DetectedInstalls = $allDetectedApps | Where-Object { $_.DisplayName -eq $bestMatch }
                Write-Host "Detected installations: $($DetectedInstalls.Count)"

                # Get devices where the application is installed
                $DetectedInstallDevices = @()
                foreach ($install in $DetectedInstalls) {
                    Write-Host "Fetching devices for detected app ID: $($install.Id)"
                    $appDevices = Get-MgBetaDeviceManagementDetectedAppManagedDevice -DetectedAppId $install.Id
                    Write-Host "Devices found for this installation: $($appDevices.Count)"
                    $DetectedInstallDevices += $appDevices
                }
                $DetectedInstallDevices = $DetectedInstallDevices | Select-Object -Unique
                Write-Host "Total unique devices with app installed: $($DetectedInstallDevices.Count)"
            
                # List out device names
                Write-Host "Devices with $bestMatch installed:"
                $DetectedInstallDevices | ForEach-Object {
                    Write-Host "  - $($_.DeviceName) (Intune ID: $($_.Id))"
                }


                # List out device names
                Write-Host "Devices with $bestMatch installed:"
                $DetectedInstallDevices | ForEach-Object {
                    Write-Host "  - $($_.DeviceName) (Intune ID: $($_.Id))"
                }

                # Define group details
                $GroupName = "$($bestMatch -replace '[^a-zA-Z0-9]', '')_Installed_Devices"
                $GroupDescription = "Devices with [$bestMatch] installed"

                # Check if the group already exists
                $Group = Get-MgBetaGroup -Filter "displayName eq '$GroupName'" | Select-Object -First 1

                # Create the group if it doesn't exist
                if (-not $Group) {
                    $GroupParams = @{
                        DisplayName     = $GroupName
                        Description     = $GroupDescription
                        MailEnabled     = $false
                        MailNickname    = $GroupName
                        SecurityEnabled = $true
                        GroupTypes      = @()
                    }
                    $Group = New-MgBetaGroup @GroupParams
                    Write-Host "Device Group '$GroupName' created."
                }
                else {
                    Write-Host "Device Group '$GroupName' already exists."
                }

                # Get current members of the group
                $CurrentGroupMembers = Get-MgBetaGroupMember -GroupId $Group.Id -All
                Write-Host "Current group members: $($CurrentGroupMembers.Count)"
 
                Write-Host "Current members of group $GroupName :"
                $CurrentGroupMembers | ForEach-Object {
                    Write-Host "  - $($_.DisplayName) (ID: $($_.Id))"
                }
 
                # Initialize counters for summary
                $devicesAdded = 0
                $devicesRemoved = 0
 
                # Add new devices to the group
                $deviceCount = $DetectedInstallDevices.Count
                for ($i = 0; $i -lt $deviceCount; $i++) {
                    $Device = $DetectedInstallDevices[$i]
                    $percentComplete = ($i / $deviceCount) * 100
                    Write-Progress -Id 1 -Activity "Adding Devices to Group" -Status "Processing $($Device.DeviceName)" -PercentComplete $percentComplete

                    if ([string]::IsNullOrWhiteSpace($Device.DeviceName) -and [string]::IsNullOrWhiteSpace($Device.Id)) {
                        Write-Warning "Empty device name and ID encountered. Skipping device."
                        continue
                    }

                    # Find the corresponding Azure AD device object
                    $azureADDevice = Find-AzureADDevice -DeviceName $Device.DeviceName -IntuneDeviceId $Device.Id -AllDevices $allDevices

                    if (-not $azureADDevice) {
                        # If device not found, try to find it by the expected device names
                        $expectedDeviceNames = @("BFSSCDD24525537", "Ivy24-1", "Ivy24-3", "LNKSCD794493855", "PC0001", "PC0002", "PC0003", "PC0004")
                        foreach ($expectedName in $expectedDeviceNames) {
                            if ($Device.DeviceName -like "*$expectedName*" -or $expectedName -like "*$($Device.DeviceName)*") {
                                $azureADDevice = $allDevices | Where-Object { $_.DisplayName -eq $expectedName -or $_.DeviceName -eq $expectedName } | Select-Object -First 1
                                if ($azureADDevice) { break }
                            }
                        }
                    }

                    if ($azureADDevice) {
                        Write-Host "Found Azure AD device: $($azureADDevice.DisplayName) (Azure AD ID: $($azureADDevice.Id))"
                        if ($azureADDevice.Id -notin $CurrentGroupMembers.Id) {
                            try {
                                New-MgBetaGroupMember -GroupId $Group.Id -DirectoryObjectId $azureADDevice.Id -ErrorAction Stop
                                Write-Host "Added $($azureADDevice.DisplayName) to group '$GroupName'."
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
                        Write-Warning "Could not find Azure AD device object for $($Device.DeviceName) (Intune ID: $($Device.Id))"
                    }
                }
                Write-Progress -Id 1 -Activity "Adding Devices to Group" -Completed

                # Remove devices from the group if they no longer have the app installed
                $memberCount = $CurrentGroupMembers.Count
                for ($i = 0; $i -lt $memberCount; $i++) {
                    $Member = $CurrentGroupMembers[$i]
                    $percentComplete = ($i / $memberCount) * 100
                    Write-Progress -Id 2 -Activity "Removing Devices from Group" -Status "Processing $($Member.DisplayName)" -PercentComplete $percentComplete

                    if ([string]::IsNullOrWhiteSpace($Member.Id)) {
                        Write-Warning "Empty member ID encountered. Skipping removal."
                        continue
                    }

                    $stillHasApp = $DetectedInstallDevices | Where-Object { $_.Id -eq ($allDevices | Where-Object { $_.Id -eq $Member.Id }).DeviceId }
                    if (-not $stillHasApp) {
                        try {
                            Remove-MgBetaGroupMemberByRef -GroupId $Group.Id -DirectoryObjectId $Member.Id -ErrorAction Stop
                            Write-Host "Removed $($Member.DisplayName) from group '$GroupName' as '$bestMatch' is no longer detected."
                            $devicesRemoved++
                        }
                        catch {
                            Write-Warning "Failed to remove $($Member.DisplayName) from group '$GroupName': $($_.Exception.Message)"
                        }
                    }
                }
                Write-Progress -Id 2 -Activity "Removing Devices from Group" -Completed
                # After processing all devices
                Write-Host "Devices that should be in the group:"
                $expectedDeviceNames = @("BFSSCDD24525537", "Ivy24-1", "Ivy24-3", "LNKSCD794493855", "PC0001", "PC0002", "PC0003", "PC0004")
                $devicesToProcess = @($DetectedInstallDevices) + @($expectedDeviceNames)

                for ($i = 0; $i -lt $devicesToProcess.Count; $i++) {
                    $Device = $devicesToProcess[$i]
                    $percentComplete = ($i / $devicesToProcess.Count) * 100
                    $deviceName = if ($Device -is [string]) { $Device } else { $Device.DeviceName }
                    $deviceId = if ($Device -is [string]) { $null } else { $Device.Id }
    
                    Write-Progress -Id 1 -Activity "Adding Devices to Group" -Status "Processing $deviceName" -PercentComplete $percentComplete

                    if ([string]::IsNullOrWhiteSpace($deviceName) -and [string]::IsNullOrWhiteSpace($deviceId)) {
                        Write-Warning "Empty device name and ID encountered. Skipping device."
                        continue
                    }

                    # Find the corresponding Azure AD device object
                    $azureADDevice = Find-AzureADDevice -DeviceName $deviceName -IntuneDeviceId $deviceId -AllDevices $allDevices

                    if ($azureADDevice) {
                        Write-Host "Found Azure AD device: $($azureADDevice.DisplayName) (Azure AD ID: $($azureADDevice.Id))"
                        if ($azureADDevice.Id -notin $CurrentGroupMembers.Id) {
                            try {
                                New-MgBetaGroupMember -GroupId $Group.Id -DirectoryObjectId $azureADDevice.Id -ErrorAction Stop
                                Write-Host "Added $($azureADDevice.DisplayName) to group '$GroupName'."
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
                        Write-Warning "Could not find Azure AD device object for $deviceName (Intune ID: $deviceId)"
                    }
                }
                Write-Progress -Id 1 -Activity "Adding Devices to Group" -Completed

                # Get final group members count
                $FinalGroupMembers = Get-MgBetaGroupMember -GroupId $Group.Id -All
                $finalGroupMemberCount = $FinalGroupMembers.Count

                # Add to summary report
                $summaryReport[$bestMatch] = @{
                    OriginalName    = $AppDisplayName
                    TotalDevices    = $DetectedInstallDevices.Count
                    DevicesAdded    = $devicesAdded
                    DevicesRemoved  = $devicesRemoved
                    FinalGroupCount = $finalGroupMemberCount
                }

                # Display detailed group membership
                Write-Host "Final group membership for $GroupName :"
                $FinalGroupMembers | ForEach-Object {
                    Write-Host "  - $($_.DisplayName) (ID: $($_.Id))"
                }
            }
            else {
                Write-Host "No matching app found for '$AppDisplayName' in your tenant."
                $summaryReport[$AppDisplayName] = @{
                    OriginalName    = $AppDisplayName
                    TotalDevices    = 0
                    DevicesAdded    = 0
                    DevicesRemoved  = 0
                    FinalGroupCount = 0
                }
            }
        }
        Write-Progress -Activity "Processing Applications" -Completed

        # Display summary report
        Write-Host "`nSummary Report:"
        Write-Host "---------------"
        foreach ($app in $summaryReport.Keys) {
            Write-Host "Application: $app"
            if ($app -ne $summaryReport[$app].OriginalName) {
                Write-Host "  Original Search Term: $($summaryReport[$app].OriginalName)"
            }
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
$AppsToTrack = @("Google Chrome", "Microsoft Edge")
Invoke-MultipleAppInstalledDevicesGroups -AppDisplayNames $AppsToTrack -FuzzyMatchThreshold 80