# Private/New-IntuneDriverProfileAssignment.ps1

function New-IntuneDriverProfileAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ProfileId,
        
        [Parameter(Mandatory = $true)]
        [string]$GroupId
    )

    try {
        Write-Verbose "Creating assignment for Profile ID: $ProfileId to Group ID: $GroupId"

        # Check existing assignments
        $uri = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles('$ProfileId')/assignments"
        $existingAssignments = (Invoke-MgGraphRequest -Method GET -Uri $uri).value
        
        # Check if assignment already exists
        if ($GroupId -in $existingAssignments.target.groupId) {
            Write-Verbose "Assignment already exists"
            return $existingAssignments | Where-Object { $_.target.groupId -eq $GroupId }
        }

        Write-Verbose "Creating new assignment..."
        
        # Prepare assignment body according to Microsoft Graph API requirements
        $assignBody = @{
            '@odata.type' = "#microsoft.graph.windowsDriverUpdateProfileAssignment"
            id = [Guid]::NewGuid().ToString()
            target = @{
                '@odata.type' = "#microsoft.graph.groupAssignmentTarget"
                deviceAndAppManagementAssignmentFilterId = $null
                deviceAndAppManagementAssignmentFilterType = "none"
                groupId = $GroupId
            }
        }

        # Create the assignment using documented endpoint structure
        $result = Invoke-MgGraphRequest -Method POST -Uri $uri `
                                      -Body ($assignBody | ConvertTo-Json -Depth 10) `
                                      -ContentType "application/json"
                                      
        Write-Verbose "Successfully created assignment"
        return $result
    }
    catch {
        $errorMessage = "Failed to create driver profile assignment: $($_)"
        Write-Error $errorMessage
        throw $errorMessage
    }
}