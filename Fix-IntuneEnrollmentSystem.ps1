$RegistryKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Enrollments",
    "HKLM:\SOFTWARE\Microsoft\Enrollments\Status",
    "HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked",
    "HKLM:\SOFTWARE\Microsoft\PolicyManager\AdmxInstalled",
    "HKLM:\SOFTWARE\Microsoft\PolicyManager\Providers",
    "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts",
    "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger",
    "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions"
)

# Remove Intune certificates
Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {
    $_.Issuer -match "Intune MDM"
} | Remove-Item

# Get EnrollmentID and unregister related scheduled tasks
$EnrollmentID = Get-ScheduledTask | 
    Where-Object { $_.TaskPath -like "*Microsoft*Windows*EnterpriseMgmt*" } | 
    Select-Object -ExpandProperty TaskPath -Unique | 
    Where-Object { $_ -like "*-*-*" } | 
    Split-Path -Leaf

Get-ScheduledTask | 
    Where-Object { $_.Taskpath -match $EnrollmentID } | 
    Unregister-ScheduledTask -Confirm:$false

# Remove registry keys related to EnrollmentID
foreach ($Key in $RegistryKeys) {
    if (Test-Path -Path $Key) {
        Get-ChildItem -Path $Key | 
            Where-Object { $_.Name -match $EnrollmentID } | 
            Remove-Item -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    }
}

# Unregister scheduled tasks for each enrollment
foreach ($enrollment in $EnrollmentID) {
    Get-ScheduledTask | 
        Where-Object { $_.Taskpath -match $enrollment } | 
        Unregister-ScheduledTask -Confirm:$false
}

Start-Sleep -Seconds 5

# Start DeviceEnroller process and handle the result
$EnrollmentProcess = Start-Process -FilePath "C:\Windows\System32\DeviceEnroller.exe" -ArgumentList "/C /AutoenrollMDM" -NoNewWindow -Wait -PassThru

if ($EnrollmentProcess.ExitCode -eq 0) {
    Write-Host "DeviceEnroller completed successfully."
} else {
    Write-Host "DeviceEnroller failed with exit code: $($EnrollmentProcess.ExitCode)"
    # You might want to add more detailed error handling here, such as logging or additional actions
}