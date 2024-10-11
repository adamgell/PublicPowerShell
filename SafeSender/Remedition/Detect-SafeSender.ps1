# Define the path for the SafeSender list
$safeSenderPath = "C:\Outlook\SafeSender.txt"

# Check if the file exists
if (Test-Path $safeSenderPath) {
    $fileInfo = Get-Item $safeSenderPath
    $lastWriteTime = $fileInfo.LastWriteTime
    $currentTime = Get-Date

    # Check if the file was last modified more than 24 hours ago
    if ($currentTime - $lastWriteTime -gt [TimeSpan]::FromHours(24)) {
        Write-Output "SafeSender list is older than 24 hours. Remediation needed."
        Exit 1
    } else {
        Write-Output "SafeSender list is up to date."
        Exit 0
    }
} else {
    Write-Output "SafeSender list does not exist. Remediation needed."
    Exit 1
}