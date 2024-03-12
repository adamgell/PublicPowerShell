<#
Version: 1.0
#>

Try {
    Start-Process .\SetUserFTA.exe -ArgumentList ".url InternetShortcut" -Wait -NoNewWindow
} 
Catch {
    Write-Warning "Not Compliant $_"
    Exit 1
}
finally {
    Exit 0
}
    






 
