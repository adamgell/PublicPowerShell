# Define the path for the SafeSender list
$safeSenderPath = "C:\Outlook\SafeSender.txt"

# Define the SafeSender list inline
$newEntries = @"
example1@domain.com
example2@domain.com
example3@domain.com
@trusteddomain.com
@google.com
@cdw.com
"@ -split "`r`n"
# Function to create directory if it doesn't exist
function EnsureDirectoryExists {
    param([string]$path)
    if (-not (Test-Path -Path (Split-Path -Parent $path) -PathType Container)) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path)
    }
}

# Function to update the SafeSender list
function UpdateSafeSenderList {
    # Ensure the directory exists
    EnsureDirectoryExists -path $safeSenderPath

    # Read existing entries or create an empty array if the file doesn't exist
    $existingEntries = @()
    if (Test-Path $safeSenderPath) {
        $existingEntries = Get-Content $safeSenderPath
    }
    
    Write-Output "----------------------------------------"
    Write-Output "`rExisting SafeSender entries: `n"$($existingEntries)
    Write-Output "----------------------------------------" 
    
    # Combine existing and new entries, removing duplicates
    $updatedEntries = ($existingEntries + $newEntries) | Select-Object -Unique | Sort-Object

    # Write the updated list back to the file
    $updatedEntries | Out-File -FilePath $safeSenderPath -Encoding UTF8

    Write-Output "SafeSender list updated successfully."
}
# Run the update function
UpdateSafeSenderList