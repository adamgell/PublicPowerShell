function Set-IntuneDriverConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$NamePrefix = $script:defaultSettings.NamePrefix,

        [Parameter(Mandatory = $false)]
        [string]$NameSuffix = $script:defaultSettings.NameSuffix,

        [Parameter(Mandatory = $false)]
        [string[]]$ExcludedModels = $script:defaultSettings.ExcludedModels,

        [Parameter(Mandatory = $false)]
        [ValidateSet('manual', 'automatic')]
        [string]$ApprovalType = $script:defaultSettings.ApprovalType,

        [Parameter(Mandatory = $false)]
        [int]$DeploymentDeferralInDays = $script:defaultSettings.DeploymentDeferralInDays
    )

    $script:defaultSettings = @{
        NamePrefix = $NamePrefix
        NameSuffix = $NameSuffix
        ExcludedModels = $ExcludedModels
        ApprovalType = $ApprovalType
        DeploymentDeferralInDays = $DeploymentDeferralInDays
    }

    return $script:defaultSettings
}