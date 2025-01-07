try
{   
$HideFileExtValue = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name HideFileExt).HideFileExt
$Hidden = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name Hidden).Hidden

if ($HideFileExtValue -eq 0 -and $Hidden -eq 1) {
    Write-Output "Extensions Hidden and hidden files are not visible"
    exit 0  
} else {
    Write-Output "Extensions Visible and hidden files are visible"
    exit 1
}
}
catch{
Write-Error $($_.Exception.Message)
exit 0
}