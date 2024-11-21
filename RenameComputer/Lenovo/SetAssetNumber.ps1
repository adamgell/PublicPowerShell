# get computer name and then split the hypen. this will get me the asset number. 
# then set the number with WinAIA.

$computername = $env:COMPUTERNAME
$assetnumber = $computername.split("-")[1]

Write-Output $assetnumber

$results = Start-Process .\WinAIA64.exe -ArgumentList "-silent -set userassetdata.asset_number=$assetnumber" -Wait -NoNewWindow
Write-Output $results

$systemEnclosure = Get-CimInstance -ClassName Win32_SystemEnclosure
$systemEnclosure | Set-CimInstance -Property @{SMBIOSAssetTag = "$assetnumber"}