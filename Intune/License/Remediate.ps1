# Remediation Script

# Define the registry key path and value
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\MfaRequiredInClipRenew"
$registryValueName = "Verify Multifactor Authentication in ClipRenew"
$registryValueData = 0  # DWORD value of 0
$sid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-4")

# Ensure the registry key and value exist and are correct
if (-not (Test-Path -Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}
Set-ItemProperty -Path $registryPath -Name $registryValueName -Value $registryValueData -Type DWORD

# Add read permissions for SID (S-1-5-4, interactive users) to the registry key with inheritance
$acl = Get-Acl -Path $registryPath
$ruleSID = New-Object System.Security.AccessControl.RegistryAccessRule($sid, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.SetAccessRule($ruleSID)
Set-Acl -Path $registryPath -AclObject $acl

Write-Output "Remediation complete."
