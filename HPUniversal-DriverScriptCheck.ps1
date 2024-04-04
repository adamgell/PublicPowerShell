# Define the target driver version
$targetDriverVersion = "61.270.01.25570"

# Define the path where the INF files are located
$infPath = "C:\Windows\INF"

# Get all OEM*.inf files in the directory
$infFiles = Get-ChildItem -Path $infPath -Filter "OEM*.inf"

# Regex pattern to match DriverVer lines
$pattern = "DriverVer=.*,${targetDriverVersion}"

# Iterate over each file and search for the target driver version
foreach ($file in $infFiles) {
    # Read the content of the current INF file
    $fileContent = Get-Content -Path $file.FullName
    
    # Search for the target driver version in the file
    foreach ($line in $fileContent) {
        if ($line -match $pattern) {
            "Driver version $targetDriverVersion found in file: $($file.Name)"
            $OEMFILE = $file.FullName
            break # Stop checking this file and move to the next
        }
    }
}


#looking for driver 61.270.01.25570
$ini = Get-Content $OEMFILE  -ErrorAction SilentlyContinue


# Regex pattern to ensure the string follows the expected format
$pattern = 'DriverVer=(\d{2}/\d{2}/\d{4}),(\d+\.\d+\.\d+\.\d+)'

# Flag to indicate if the driver was found
$driverFound = $false

# Iterate through each line of the file
foreach ($line in $ini) {
    # Check if the current line matches the pattern
    if ($line -match $pattern) {
        # Check if the version part matches the desired driver version
        if ($matches[2] -eq "61.270.01.25570") {
            # Split the matched line by comma
            $parts = $line -split ","
            # Extract and display the date part and version part
            "Date Part: $($parts[0].Replace('DriverVer=', ''))"
            "Version Part: $($parts[1])"
            $driverFound = $true
		Write-Output "Driver found and its the right version"
		Exit 0 # Stop searching once the driver is found
        }
    }
}

# If the driver was not found in the file
if (-not $driverFound) {
    "The specified driver version was not found."
	exit 1
}