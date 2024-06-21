#Delete existing scheduled task if it exists
$taskName = "Computer Restart"
# Query the system for the task. If it doesn't exist, an error message will be returned
$taskExists = schtasks /query /TN $($taskName) 2>&1 | Select-String -Pattern "ERROR: The system cannot find the file specified." -Quiet

# If the task exists (no error message), delete it
if ($taskExists -eq $null) {
    $taskResult = schtasks /delete /TN $($taskName) /f
    # If the task was successfully deleted, print a success message
    if ($taskResult -match 'SUCCESS') {
        Write-Host "Deleted $($taskName) task"
    }
    else {
        # If the task could not be deleted, print a failure message
        Write-Host "Failed to delete $($taskName) task"
    }
}

#Copy necessary files from intunewin package to local PC
$resourcePath = "C:\ProgramData\IntuneTasks"

# If the destination directory doesn't exist, create it
if (!(Test-Path $resourcePath)) {
    mkdir $resourcePath
}

# Define the files to be copied
$packageFiles = @(
    "Computer Restart.xml"
)

# Copy each file in the list to the destination directory
foreach ($file in $packageFiles) {
    Copy-Item -Path "$($PSScriptRoot)\$($file)" -Destination "$($resourcePath)" -Force
}

# For each file in the list, if it's an XML file, create a new scheduled task from it
foreach ($file in $packageFiles) {
    if ($file -match '.xml') {
        $name = $file.Split('.')[0]
        $taskResult = schtasks /create /TN $($name) /xml "$($resourcePath)\$($file)" /f
        # If the task was successfully created, print a success message
        if ($taskResult -match 'SUCCESS') {
            Write-Host "Created $($name) task"
        }
        else {
            # If the task could not be created, print a failure message and set a flag
            Write-Host "Failed to create $($name) task"
            $tasksCreated = $false
        }
    }
}