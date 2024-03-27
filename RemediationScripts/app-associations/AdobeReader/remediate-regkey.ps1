<#
Version: 1.0
#>

Try {
    Start-Process "C:\temp\SetUserFTA.exe" -ArgumentList ".pdf, Acrobat.Document.DC" -Wait -NoNewWindow
} 
Catch {
    Write-Warning "Not Compliant $_"
    Exit 1
}
finally {
    Exit 0
}