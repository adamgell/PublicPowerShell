$RegistrySettingsToValidate = @(
    [pscustomobject]@{
        Hive  = 'HKLM:\'
        Key   = 'Software\Microsoft\CCMSetup'
    },
    [pscustomobject]@{
        Hive  = 'HKLM:\'
        Key   = 'SOFTWARE\Microsoft\SMS'
    }
)


Foreach ($reg in $RegistrySettingsToValidate) {

    $DesiredPath          = "$($reg.Hive)$($reg.Key)"

    # Check if the registry key path exists
    If (Test-Path -Path $DesiredPath) {
        $CurrentKeyError -= [RegKeyError]::Path
        Write-Output "Found any registry keys. Running remedition to forcely remove all SCCM bits"
        Exit 1
    }
    else {
        Write-Output "Not found any registry keys. Exiting script"
        Exit 0
    }
}