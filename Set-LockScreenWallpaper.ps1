function Restart-Explorer() {
	Stop-Process -ProcessName explorer -Confirm:$false -Force -ErrorAction SilentlyContinue
}
function Set-Lockscreen {
	$RegKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"

	$DesktopPath = "DesktopImagePath"
	$DesktopStatus = "DesktopImageStatus"
	$DesktopUrl = "DesktopImageUrl"
	$LockScreenPath = "LockScreenImagePath"
	$LockScreenStatus = "LockScreenImageStatus"
	$LockScreenUrl = "LockScreenImageUrl"

	$StatusValue = "1"
	 
	$DesktopImageValue = "C:\ProgramData\IntuneFiles\VSDWallpaper2018.jpg"  #Change as per your needs
	$LockScreenImageValue = "C:\ProgramData\IntuneFiles\VSDWallpaper2018.jpg"  #Change as per your needs
	
	#Delete keys if exists 
	Remove-Item $RegKeyPath

	IF (!(Test-Path $RegKeyPath)) {
		New-Item -Path $RegKeyPath -Force | Out-Null

        #desktop
		New-ItemProperty -Path $RegKeyPath -Name $DesktopStatus -Value $StatusValue -PropertyType DWORD -Force | Out-Null
		New-ItemProperty -Path $RegKeyPath -Name $DesktopPath -Value $DesktopImageValue -PropertyType STRING -Force | Out-Null
		New-ItemProperty -Path $RegKeyPath -Name $DesktopUrl -Value $DesktopImageValue -PropertyType STRING -Force | Out-Null
		
        #lockscreen
        New-ItemProperty -Path $RegKeyPath -Name $LockScreenStatus -Value $StatusValue -PropertyType DWORD -Force | Out-Null
		New-ItemProperty -Path $RegKeyPath -Name $LockScreenPath -Value $LockScreenImageValue -PropertyType STRING -Force | Out-Null
		New-ItemProperty -Path $RegKeyPath -Name $LockScreenUrl -Value $LockScreenImageValue -PropertyType STRING -Force | Out-Null
	}

	ELSE {
		
		#desktop
		New-ItemProperty -Path $RegKeyPath -Name $DesktopPath -Value $DesktopImageValue -PropertyType STRING -Force | Out-Null
		New-ItemProperty -Path $RegKeyPath -Name $DesktopUrl -Value $DesktopImageValue -PropertyType STRING -Force | Out-Null
        New-ItemProperty -Path $RegKeyPath -Name $DesktopStatus -Value $Statusvalue -PropertyType DWORD -Force | Out-Null
        #lockscreen
        New-ItemProperty -Path $RegKeyPath -Name $LockScreenStatus -Value $value -PropertyType DWORD -Force | Out-Null
		New-ItemProperty -Path $RegKeyPath -Name $LockScreenPath -Value $LockScreenImageValue -PropertyType STRING -Force | Out-Null
		New-ItemProperty -Path $RegKeyPath -Name $LockScreenUrl -Value $LockScreenImageValue -PropertyType STRING -Force | Out-Null
	}

	Restart-Explorer
}


#Copy necessary files from intunewin package to local PC
$resourcePath = "C:\ProgramData\IntuneFiles"

if (!(Test-Path $resourcePath)) {
	mkdir $resourcePath
}

$packageFiles = @(
	"VSDWallpaper2018.jpg"
)

foreach ($file in $packageFiles) {
	Copy-Item -Path "$($PSScriptRoot)\$($file)" -Destination "$($resourcePath)" -Force -Verbose
}

Set-Lockscreen 