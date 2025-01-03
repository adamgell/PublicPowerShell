function Get-LenovoFriendlyName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MTM
    )
    
    try {
        $URL = "https://download.lenovo.com/bsco/public/allModels.json"
        $webContent = Invoke-RestMethod -Uri $URL -Method GET
        $currentModel = ($webContent | Where-Object {
            ($_ -like "*$MTM*") -and 
            ($_ -notlike "*-UEFI Lenovo*") -and 
            ($_ -notlike "*dTPM*") -and 
            ($_ -notlike "*Asset*") -and 
            ($_ -notlike "*fTPM*")
        })[0]
        
        if ($currentModel) {
            return ($currentModel.name.split("("))[0].TrimEnd()
        }
        Write-Warning "No friendly name found for Lenovo MTM: $MTM"
        return $MTM
    }
    catch {
        Write-Warning "Failed to retrieve Lenovo friendly name: $_"
        return $MTM
    }
}