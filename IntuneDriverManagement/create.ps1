# Create-ModuleStructure.ps1
param(
    [Parameter(Mandatory = $true)]
    [string]$ModuleName,
    [Parameter(Mandatory = $false)]
    [string]$Path = $PSScriptRoot
)

# Create main module directory
$modulePath = Join-Path -Path $Path -ChildPath $ModuleName
New-Item -Path $modulePath -ItemType Directory -Force

# Create module manifest and module loader files
$null = New-Item -Path (Join-Path -Path $modulePath -ChildPath "$ModuleName.psd1") -ItemType File
$null = New-Item -Path (Join-Path -Path $modulePath -ChildPath "$ModuleName.psm1") -ItemType File

# Create subdirectories
$directories = @(
    'classes',
    'config',
    'Public',
    'Private',
    'Tests',
    'Tests\Unit',
    'Tests\Integration'
)

foreach ($dir in $directories) {
    $dirPath = Join-Path -Path $modulePath -ChildPath $dir
    New-Item -Path $dirPath -ItemType Directory -Force
}

# Create initial files
$files = @{
    'classes\IntuneDevice.ps1' = ''
    'config\Default.psd1' = ''
    'Public\Connect-IntuneDriverManagement.ps1' = ''
    'Public\Set-IntuneDriverConfiguration.ps1' = ''
    'Public\Start-IntuneDriverUpdate.ps1' = ''
    'Private\Get-IntuneDeviceInfo.ps1' = ''
    'Private\Get-LenovoFriendlyName.ps1' = ''
    'Private\New-IntuneDriverGroup.ps1' = ''
    'Private\New-IntuneDriverProfile.ps1' = ''
    'Private\New-IntuneDriverProfileAssignment.ps1' = ''
    'Tests\Unit\IntuneDevice.Tests.ps1' = ''
    'Tests\Unit\Connect-IntuneDriverManagement.Tests.ps1' = ''
    'Tests\Integration\GroupCreation.Tests.ps1' = ''
    'Tests\Integration\ProfileAssignment.Tests.ps1' = ''
}

foreach ($file in $files.Keys) {
    $filePath = Join-Path -Path $modulePath -ChildPath $file
    New-Item -Path $filePath -ItemType File -Force
}

# Generate basic module manifest
$manifestParams = @{
    Path = Join-Path -Path $modulePath -ChildPath "$ModuleName.psd1"
    RootModule = "$ModuleName.psm1"
    ModuleVersion = '0.1.0'
    Author = $env:USERNAME
    Description = 'PowerShell module for managing Intune drivers'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Connect-IntuneDriverManagement',
        'Set-IntuneDriverConfiguration',
        'Start-IntuneDriverUpdate'
    )
}
New-ModuleManifest @manifestParams

Write-Host "Module structure created at: $modulePath"

