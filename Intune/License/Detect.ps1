# Detection Script

# Define the registry key path and value
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\MfaRequiredInClipRenew"
$registryValueName = "Verify Multifactor Authentication in ClipRenew"
$expectedValueData = 0  # DWORD value of 0
#$sid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-4")
$interactiveGroupName = "NT AUTHORITY\INTERACTIVE"

# Function to check registry key and value
function Test-RegistryValue {
    param (
        [string]$path,
        [string]$name,
        [int]$expectedValue
    )
    if (Test-Path -Path $path) {
        $currentValue = Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
        if ($null -ne $currentValue) {
            return $currentValue.$name -eq $expectedValue
        }
    }
    return $false
}

# Function to check ACL for INTERACTIVE group
function Test-RegistryAcl {
    param (
        [string]$path,
        [string]$groupName
    )
    $acl = Get-Acl -Path $path
    foreach ($access in $acl.Access) {
        if ($access.IdentityReference -eq $groupName -and $access.RegistryRights -band "FullControl" -and $access.InheritanceFlags -band "ContainerInherit,ObjectInherit") {
            return $true
        }
    }
    return $false
}

# Check registry key, value, and permissions
$keyExists = Test-Path -Path $registryPath
$valueCorrect = Test-RegistryValue -path $registryPath -name $registryValueName -expectedValue $expectedValueData
$aclCorrect = Test-RegistryAcl -path $registryPath -groupName $interactiveGroupName

if ($keyExists -and $valueCorrect -and $aclCorrect) {
    Write-Output $keyExists $valueCorrect $aclCorrect
    Write-Output "Compliant."
    #exit 0
} else {
    Write-Output $keyExists $valueCorrect $aclCorrect
    Write-Output "Not Compliant. $error"
    #exit 1
}
