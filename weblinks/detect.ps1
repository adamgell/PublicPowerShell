
$icons = "C:\Users\Public\Desktop\weblink.lnk", "C:\Users\Public\Desktop\weblink.lnk"
$icons = Test-Path $icons

if($icons -eq $false) {
    Write-Host "icons not found"
    Exit 1
}
else {
    Write-Host "Icons Found"
    Exit 0
}