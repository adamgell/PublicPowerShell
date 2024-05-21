#Delete existing scheduled task if it exists
$taskName = "Computer Restart"
# Query the system for the task. If it doesn't exist, an error message will be returned
$taskExists = schtasks /query /TN $($taskName) 2>&1 | Select-String -Pattern "ERROR: The system cannot find the file specified." -Quiet

# If the task exists (no error message), task exists
if ($null -eq $taskExists) {
    Write-Output "task exists"
    Exit 0
} else {
    Write-Output "task does not exist"
    Exit 1
}

