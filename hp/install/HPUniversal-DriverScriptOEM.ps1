# Define the target driver version
$targetDriverVersion = "61.270.01.25570"

# Define the path where the INF files are located
$infPath = "C:\Windows\INF"

# Get all OEM*.inf files in the directory
$infFiles = Get-ChildItem -Path $infPath -Filter "OEM*.inf"

# Regex pattern to match DriverVer lines
$pattern = "HP\s+Universal\s+Printing\s+PCL\s+6"

# Iterate over each file and search for the target driver version
foreach ($file in $infFiles) {
    # Read the content of the current INF file
    $fileContent = Get-Content -Path $file.FullName
    
    # Search for the target driver version in the file
    foreach ($line in $fileContent) {
        if ($line -match $pattern) {
            "Driver version $targetDriverVersion found in file: $($file.Name)"
            break # Stop checking this file and move to the next
        }
    }
}
