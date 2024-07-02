Get-AzureADGroup -ALL -Property * | where{$_.GroupTypes -eq "DynamicMembership"} | Select DisplayName, Description, MembershipRule
