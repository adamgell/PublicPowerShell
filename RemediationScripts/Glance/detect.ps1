# Script: detect.ps1
# Purpose: Detects if Glance by Mirametrix is installed and if its scheduled task exists
# Author: Adam Gell CDW
# Last Modified: 2024-10-29

# Initialize detection flags
$taskExists = $false
$appInstalled = $false

# Define constants
$APP_NAME = "MirametrixInc.GlancebyMirametrix"
$TASK_NAME = "GlanceDiscovery"

# Check for the Glance application package (including all users)
Write-Verbose "Checking for Glance application package..."
$app = Get-AppXPackage -Name $APP_NAME -AllUsers
if ($null -ne $app) {
    $appInstalled = $true
    Write-Verbose "Glance application found"
}

# Check for the Glance scheduled task
Write-Verbose "Checking for Glance scheduled task..."
$tasks = Get-ScheduledTask | Where-Object {$_.TaskName -like "*$TASK_NAME*"}
if($null -ne $tasks) {
    $taskExists = $true
    Write-Verbose "Glance scheduled task found"
}

# Evaluate results and output status
if($taskExists -or $appInstalled) {
    Write-Output "Glance is installed and/or scheduled task exists... remediation required"
    exit 1
} else {
    Write-Output "Glance is not installed and no scheduled task exists... no action required"
    exit 0
}