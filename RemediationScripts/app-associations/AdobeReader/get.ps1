$FTA = .\SetUserFTA.exe get

$hashTable = @{}
$FTA.Split("`n") | ForEach-Object {
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

# The code to create the hash table goes here...

# Value you want to search for
$searchValue = ".url"

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
} else {
    Write-Host "Value not found!"
}

