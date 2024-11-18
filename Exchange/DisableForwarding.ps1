Import-Module ExchangeOnlineManagement

# Connect to Exchange Online
Connect-ExchangeOnline

# Get mailboxes with forwarding
$mailboxes = Get-Mailbox -ResultSize Unlimited | Where-Object {
    $_.ForwardingAddress -ne $null -or 
    $_.ForwardingSmtpAddress -ne $null -or 
    $_.ForwardingsmtpAddress -ne $null
}

# Create report for before/after status
$report = @()

foreach ($mailbox in $mailboxes) {
    # Store original values
    $originalStatus = [PSCustomObject]@{
        Mailbox = $mailbox.UserPrincipalName
        DisplayName = $mailbox.DisplayName
        OriginalForwardingAddress = $mailbox.ForwardingAddress
        OriginalForwardingSmtpAddress = $mailbox.ForwardingSmtpAddress
        OriginalDeliverToMailboxAndForward = $mailbox.DeliverToMailboxAndForward
        ActionTaken = "Forwarding Disabled"
        Status = "Success"
    }
    
    try {
        # Disable forwarding
        Set-Mailbox -Identity $mailbox.UserPrincipalName -ForwardingAddress $null -ForwardingSmtpAddress $null -DeliverToMailboxAndForward $false
    }
    catch {
        $originalStatus.Status = "Failed: $($_.Exception.Message)"
    }
    
    $report += $originalStatus
}

# Export results
#$report | Export-Csv -Path "ForwardingDisabled_$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation

# Display results
$report | Format-Table -AutoSize

# Disconnect
Disconnect-ExchangeOnline -Confirm:$false