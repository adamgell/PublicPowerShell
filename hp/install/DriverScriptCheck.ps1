#looking for driver 61.270.01.25570
$ini = Get-Content C:\Windows\INF\oem52.inf  -ErrorAction SilentlyContinue


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
	Exit 1
}