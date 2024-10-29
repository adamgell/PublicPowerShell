# Script: rem.ps1
# Purpose: Removes Glance by Mirametrix application and its scheduled task
# Author: Adam Gell CDW
# Last Modified: 2024-10-29

# Define constants
$APP_NAME = "MirametrixInc.GlancebyMirametrix"
$TASK_NAME = "GlanceDiscovery"

# Function to remove the Glance application
function Remove-GlanceApp {
    Write-Verbose "Attempting to remove Glance application..."
    try {
        # Remove for current user
        Get-AppxPackage -Name $APP_NAME | Remove-AppxPackage
        # Remove for all users
        Get-AppxPackage -Name $APP_NAME -AllUsers | Remove-AppxPackage -AllUsers
        Write-Verbose "Application removal commands executed successfully"
    }
    catch {
        Write-Error "Error removing Glance application: $_"
        return $false
    }
    return $true
}

# Function to remove the Glance scheduled task
function Remove-GlanceTask {
    Write-Verbose "Attempting to remove Glance scheduled task..."
    try {
        $task = Get-ScheduledTask | Where-Object {$_.TaskName -like "*$TASK_NAME*"}
        if ($null -ne $task) {
            Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false
            Write-Verbose "Scheduled task removed successfully"
            return $true
        }
    }
    catch {
        Write-Error "Error removing scheduled task: $_"
        return $false
    }
    return $false
}

# Execute removal functions
$appRemoved = Remove-GlanceApp
$taskRemoved = Remove-GlanceTask

# Verify removal was successful
$taskExists = $false
$appInstalled = $false

# Check if app still exists
$app = Get-AppXPackage -Name $APP_NAME -AllUsers
if ($null -ne $app) {
    $appInstalled = $true
}

# Check if task still exists
$tasks = Get-ScheduledTask | Where-Object {$_.TaskName -like "*$TASK_NAME*"}
if($null -ne $tasks) {
    $taskExists = $true
}

# Output results
if($taskExists -eq $false -and $appInstalled -eq $false) {
    Write-Host "Successfully removed Glance application and scheduled task"
    exit 0
} else {
    Write-Host "Warning: Some components may still remain. Please check logs for details."
    exit 1
}