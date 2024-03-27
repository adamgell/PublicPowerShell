<#
Version: 1.0
#>


Try {
    $TestPath = Test-Path "C:\temp\SetUserFTA.exe"
    if($TestPath){
        Write-Host "File already exists"
    } else {
        $URI = "https://github.com/adamgell/PublicPowerShell/raw/main/RemediationScripts/app-associations/SetUserFTA.exe"
        invoke-webrequest -uri $URI -outfile "C:\temp\SetUserFTA.exe"
    }
    
    $FTA = cmd /c "C:\temp\SetUserFTA.exe get"
    $hashTable = @{}
    $FTA | ForEach-Object {
        $split = $_.Split(',')
        $extension = $split[0].Trim()
        $programID = $split[1].Trim()
    
        if ($hashTable.ContainsKey($programID)) {
            $hashTable[$programID] += $extension
        }
        else {
            $hashTable[$programID] = @($extension)
        }

    }
    
    # Value you want to search for
    $searchValue = ".pdf"
    
    # Check if the value exists
    $found = $false
    foreach ($key in $hashTable.Keys) {
        if ($hashTable[$key] -contains $searchValue) {
            $found = $true
            $currentassoc = $key
            break
        }
    }

    if ($found) {
        Write-Host "Value found! Assigned to $currentassoc"
        if ($currentassoc -eq "InternetShortcut") {
            Write-Host "$searchValue is assigned to $currentassoc and that is compliant"
            Exit 0
        } else {
            Write-Host "$searchValue is assigned to $currentassoc and that is not compliant"
            Exit 1
        }
        exit 1
    }
    else {
        Write-Host "$searchValue is assigned to $currentassoc and that is not compliant"
        Exit 1
    }    
} 
Catch {
    Write-Warning "$searchValue is assigned to $currentassoc and that is not compliant"
    Exit 1
}
finally {
    Exit 0
}
    






 

 
