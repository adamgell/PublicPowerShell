# Get-AutopilotDeviceObjectIDs Script Documentation

## Overview
This PowerShell script retrieves Entra Device Object IDs for devices enrolled in Windows Autopilot by matching their serial numbers. The script generates a CSV file formatted for bulk device group management in Microsoft Entra ID (Azure AD).

## Prerequisites
- PowerShell 5.1 or higher
- PowerShellGet version 2.2.5 or higher
- Required PowerShell modules (automatically installed if missing):
  - WindowsAutopilotIntune
  - Microsoft.Graph.Authentication
  - Microsoft.Graph.Entra

## Required Permissions
The account running the script needs the following Microsoft Graph permissions:
- DeviceManagementServiceConfig.Read.All
- Device.Read.All

## Input File Format
The script expects a CSV file named `serials.csv` in the same directory as the script with the following format:

```csv
SerialNumber
1234567890
9876543210
```

## Output File Format
The script generates a CSV file named `ObjectIDList.csv` with the following format:
```csv
version:v1.0
[memberObjectIdOrUpn]
objectId1
objectId2
```

This format is compatible with bulk device group management in Microsoft Entra ID.

## Installation

1. Ensure you have the required PowerShell version installed
2. Update PowerShellGet if needed:
```powershell
Install-Module -Name PowerShellGet -Force -AllowClobber -MinimumVersion 2.2.5
```
3. Place the script and your serials.csv file in the same directory

## Usage

1. Open PowerShell as an administrator
2. Navigate to the script directory
3. Run the script:
```powershell
.\Get-AutopilotDeviceObjectIDs.ps1
```

The script will:
1. Check and install required modules
2. Verify prerequisites
3. Connect to Microsoft Graph
4. Process each serial number
5. Generate ObjectIDList.csv with the results
6. Create a detailed log file

## Features
- Automatic module installation and version checking
- Detailed console output with color coding
- Progress tracking
- Success/failure statistics
- Comprehensive error handling
- Transcript logging
- Input validation
- Existing file protection (prompts before overwriting)

## Output Files
The script generates two files:
1. `ObjectIDList.csv` - Contains the device Object IDs in the required format
2. `script_log.txt` - Detailed log of all operations and any errors encountered

## Statistics and Reporting
The script provides:
- Total devices processed
- Successfully processed devices count
- Failed devices count
- Success rate percentage
- Detailed logging of each operation

## Troubleshooting
Common issues and solutions:

1. PowerShellGet version too low:
   - Update PowerShellGet and restart PowerShell

2. Missing serials.csv:
   - Ensure serials.csv exists in the same directory as the script
   - Verify CSV format has "SerialNumber" header

3. Permission errors:
   - Ensure you have the required Graph API permissions
   - Run PowerShell as administrator if needed

4. Module installation errors:
   - Run PowerShell as administrator
   - Check internet connectivity
   - Clear PowerShell module cache if needed

## Error Messages
The script uses color-coded messages:
- Green: Success messages
- Yellow: Warnings and non-critical errors
- Red: Critical errors
- Cyan: Summary information

## Logging
All operations are logged to `script_log.txt`, including:
- Module installations
- Device processing attempts
- Errors and warnings
- Final statistics

## Support
For issues with:
- Microsoft Graph permissions: Contact your Microsoft 365 administrator
- Module installation: Check [PowerShell Gallery](https://www.powershellgallery.com)
- Script errors: Review script_log.txt for detailed error messages

## Best Practices
1. Always run a test with a small set of serial numbers first
2. Keep a backup of your serials.csv file
3. Review the log file after execution
4. Update PowerShellGet before running if prompted

## Version History
- 1.0: Initial release
  - Basic functionality for retrieving Object IDs
  - CSV input/output handling
  - Error logging

## Known Limitations
- Processes one device at a time
- Requires manual confirmation for file overwrites
- Must be run from script directory

## Security Notes
- Script uses secure Graph authentication
- No sensitive data is stored in plain text
- Logs may contain device identifiers