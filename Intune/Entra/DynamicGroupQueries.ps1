# Authentication parameters
$clientId = ""
$tenantId = ""
$clientSecret = ""

# Acquire an access token
$body = @{
    grant_type    = "client_credentials"
    scope         = "https://graph.microsoft.com/.default"
    client_id     = $clientId
    client_secret = $clientSecret
}
$tokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -ContentType "application/x-www-form-urlencoded" -Body $body
$accessToken = $tokenResponse.access_token

# Define the URI to get the groups
$uri = "https://graph.microsoft.com/v1.0/groups"

# Set the headers
$headers = @{
    "Authorization" = "Bearer $accessToken"
    "Content-Type"  = "application/json"
}

# Get all groups
$groups = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers

# Create an array to store the results
$dynamicGroups = @()

# Extract dynamic membership rules
foreach ($group in $groups.value) {
    if ($group.groupTypes -contains "DynamicMembership") {
        $dynamicGroups += [PSCustomObject]@{
            GroupName                  = $group.displayName
            MembershipRule             = $group.membershipRule
            MembershipRuleProcessingState = $group.membershipRuleProcessingState
        }
    }
}

# Export the results to a CSV file
$dynamicGroups | Export-Csv -Path "DynamicGroupMembershipRules.csv" -NoTypeInformation

Write-Output "Dynamic group membership rules have been exported to DynamicGroupMembershipRules.csv"
