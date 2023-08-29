$tagdirectory = "$env:AppData\Microsoft\UnpinApps"

try {
    $store = "$($tagdirectory)\Store.tag"
    $mail = "$($tagdirectory)\Mail.tag" 
    
    if(Test-Path $mail) {
        Write-Output "Found Mail.tag"
    } else {
        Write-Output "Not found Mail.tag"
        Exit 1
    }
    
    if(Test-Path $store) {
        Write-Output "Found Store.tag"
    }else {
        Write-Output "Not found Store.tag"
        Exit 1
    }
    exit 0
}
catch {
    Write-Output $_
    exit 1
}