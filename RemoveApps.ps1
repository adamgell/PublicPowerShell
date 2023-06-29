<#
Microsoft Windows Unquoted Service Path Enumeration
Nessus found the following service with an untrusted path : SbieSvc : C:\Program Files\Sandboxie-Plus\SbieSvc.exe

Paint 3d
Path : C:\Program Files\WindowsApps\Microsoft.MSPaint_1.0.46.0_x64__8wekyb3d8bbwe Installed version : 1.0.46.0 Fixed version : 6.2105.4017.0

Windows Terminal
Path : C:\Program Files\WindowsApps\Microsoft.WindowsTerminal_1.12.10983.0_x64__8wekyb3d8bbwe Installed version : 1.12.10983.0 Fixed version : 1.15.2874
#>

$pathstoremove = "C:\Program Files\WindowsApps\Microsoft.MSPaint_1.0.46.0_x64__8wekyb3d8bbwe","C:\Program Files\WindowsApps\Microsoft.WindowsTerminal_1.12.10983.0_x64__8wekyb3d8bbwe"
foreach ($path in $pathstoremove) {
    Write-Host "Removing $path"
    Remove-AppxProvisionedPackage -Online -PackageName $path -AllUsers | Out-Null
    Remove-AppxPackage -Online -Package $path | Out-Null
}