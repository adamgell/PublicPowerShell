# Install and import Exchange Online module if not already installed
# Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber
Import-Module ExchangeOnlineManagement

# Connect to Exchange Online
Connect-ExchangeOnline

# Get all mailboxes with forwarding configurations
$mailboxes = Get-Mailbox -ResultSize Unlimited | Where-Object {
    $_.ForwardingAddress -ne $null -or 
    $_.ForwardingSmtpAddress -ne $null -or 
    $_.ForwardingsmtpAddress -ne $null
}

# Create report array
$report = @()

foreach ($mailbox in $mailboxes) {
    $forwardInfo = [PSCustomObject]@{
        Mailbox = $mailbox.UserPrincipalName
        DisplayName = $mailbox.DisplayName
        ForwardingAddress = $mailbox.ForwardingAddress
        ForwardingSmtpAddress = $mailbox.ForwardingSmtpAddress
        DeliverToMailboxAndForward = $mailbox.DeliverToMailboxAndForward
    }
    $report += $forwardInfo
}

# Export to CSV
# $report | Export-Csv -Path "MailboxForwarding_$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation

# Display results in console
$report | Format-Table -AutoSize