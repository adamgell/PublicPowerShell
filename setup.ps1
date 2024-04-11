# Tenant Id
$TenantId = "8db2d067-abd7-4b13-b2a5-3924ed273b1a"
# List of permission names
$RolesToAssign = @(
    "DeviceManagementApps.Read.All"
    "DeviceManagementConfiguration.Read.All"
    "DeviceManagementServiceConfig.Read.All"
    "CloudPC.Read.All"
    "DeviceManagementRBAC.Read.All"
    "GroupMember.Read.All"
)
#  DisplayName of the Enterprise App you are assigning permissions to
$EnterpriseAppName = "IntuneAssignmentsReport"
# Connect to Graph
Import-Module Microsoft.Graph.Applications
Connect-Graph -TenantId $TenantId -NoWelcome
# Get the service principals
$GraphApp = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'" # Microsoft Graph
$EnterpriseApp = Get-MgServicePrincipal -Filter "DisplayName eq '$EnterpriseAppName'"
# Assign the roles
foreach ($Role in $RolesToAssign) {
    $Role = $GraphApp.AppRoles | Where-Object { $_.Value -eq $Role }
    $params = @{
        principalId = $EnterpriseApp.Id
        resourceId = $GraphApp.Id
        appRoleId = $Role.Id
    }
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $EnterpriseApp.Id -BodyParameter $params
}