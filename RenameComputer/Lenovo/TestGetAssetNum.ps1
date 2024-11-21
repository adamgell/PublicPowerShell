$results = Start-Process .\WinAIA64.exe -ArgumentList "-silent -output-file assetnum.txt -get userassetdata" -Wait -NoNewWindow
$assetTag = (Get-Content assetnum.txt).Split("=")[1]
$assetTag