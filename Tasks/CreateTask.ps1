#Delete existing scheduled task if it exists
$taskName = "ComputerRestart"
$taskExists = schtasks /query /TN $($taskName) 2>&1 | Select-String -Pattern "ERROR: The system cannot find the file specified." -Quiet

if ($taskExists -eq $null) {
	$taskResult = schtasks /delete /TN $($taskName) /f
	if ($taskResult -match 'SUCCESS') {
		Write-Host "Deleted $($taskName) task"
	}
	else {
		Write-Host "Failed to delete $($taskName) task"
	}
}

#Copy necessary files from intunewin package to local PC
$resourcePath = "C:\ProgramData\IntuneTasks"

if (!(Test-Path $resourcePath)) {
	mkdir $resourcePath
}

$packageFiles = @(
	"ComputerRestart.xml"
)

foreach ($file in $packageFiles) {
	Copy-Item -Path "$($PSScriptRoot)\$($file)" -Destination "$($resourcePath)" -Force
}


foreach ($file in $packageFiles) {
	if ($file -match '.xml') {
		$name = $file.Split('.')[0]
		$taskResult = schtasks /create /TN $($name) /xml "$($resourcePath)\$($file)" /f
		if ($taskResult -match 'SUCCESS') {
			Write-Host "Created $($name) task"
		}
		else {
			Write-Host "Failed to create $($name) task"
			$tasksCreated = $false
		}
	}
}
