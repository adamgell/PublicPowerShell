./teamsbootstrapper -x

Get-AppPackage -AllUsers *MSTeams* | Remove-AppPackage -AllUsers -ErrorAction SilentlyContinue
