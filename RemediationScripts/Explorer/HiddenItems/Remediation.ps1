try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name HideFileExt -Value 0 -ErrorAction Stop
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name Hidden -Value 1 -ErrorAction Stop
    # restart explorer forcely
    Stop-Process -Name explorer -Force
    exit 0
}
catch {
    return $($_.Exception.Message)
    exit 1
}