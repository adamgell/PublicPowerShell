function New-IntuneDriverProfile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$GroupName,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('manual', 'automatic')]
        [string]$ApprovalType = 'manual',

        [Parameter(Mandatory = $false)]
        [int]$DeploymentDeferralInDays = 7
    )

    try {
        Write-Verbose "Creating driver update profile for group: $GroupName"
        
        # Get existing profiles to check for duplicates
        $uri = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles"
        $existingProfiles = (Invoke-MgGraphRequest -Method GET -Uri $uri).value
        $existingProfile = $existingProfiles | Where-Object { $_.displayName -eq $GroupName }

        if ($existingProfile) {
            Write-Verbose "Profile already exists: $GroupName"
            return $existingProfile
        }

        Write-Verbose "Creating new profile with approval type: $ApprovalType"
        
        # Prepare profile body
        $profileBody = @{
            '@odata.type' = "#microsoft.graph.windowsDriverUpdateProfile"
            displayName = $GroupName
            approvalType = $ApprovalType
            roleScopeTagIds = @()
            ContentType = "application/json"
        }

        # Add deployment deferral if automatic approval
        if ($ApprovalType -eq "automatic") {
            $profileBody.Add("deploymentDeferralInDays", $DeploymentDeferralInDays)
        }

        # Create the profile
        $profile = Invoke-MgGraphRequest -Method POST -Uri $uri -Body ($profileBody | ConvertTo-Json)
        Write-Verbose "Successfully created profile: $($profile.id)"
        
        return $profile
    }
    catch {
        $errorMessage = "Failed to create driver update profile: $($_)"
        Write-Error $errorMessage
        throw $errorMessage
    }
}