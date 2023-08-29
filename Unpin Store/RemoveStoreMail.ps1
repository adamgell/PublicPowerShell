$date = (Get-Date)
$tagdirectory = "$env:AppData\Microsoft\UnpinApps"

# Create a tag file just so Intune knows this was installed
if (-not (Test-Path "$($tagdirectory)")) {
    Mkdir "$($tagdirectory)"
}

((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | Where-Object { $_.Name -eq "Microsoft Store" }).Verbs() | Where-Object { $_.Name.replace('&', '') -match 'Unpin from taskbar' } | ForEach-Object { $_.DoIt(); $exec = $true }
Set-Content -Path "$($tagdirectory)\Store.tag" -Value "Installed $date"
((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | Where-Object { $_.Name -eq "Mail" }).Verbs() | Where-Object { $_.Name.replace('&', '') -match 'Unpin from taskbar' } | ForEach-Object { $_.DoIt(); $exec = $true }
Set-Content -Path "$($tagdirectory)\Mail.tag" -Value "Installed $date"



