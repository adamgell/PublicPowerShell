#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })] # Ensure the ISO file exists
    [string]$IsoPath,
    [Parameter(Mandatory = $true)]
    [string]$VMName,
    [uint64]$VHDXSizeBytes = 120GB,
    [int64]$MemoryStartupBytes = 4GB,
    [int64]$ProcessorCount = 2,
    [ArgumentCompleter({
        param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
        (Get-VMSwitch).Name | Where-Object { $_ -like "$WordToComplete*" }
    })]
    [string]$SwitchName = "Default Switch"
)

$ErrorActionPreference = 'Stop'

try {
    # Get default VHD path (requires administrative privileges)
    $VMHost = Get-VMHost
    $VirtualHardDiskPath = $VMHost.VirtualHardDiskPath

    $PathAdd = New-Guid
    $VhdxPath = Join-Path $VirtualHardDiskPath "$VMName-$PathAdd.vhdx"

    # Create VM with combined commands where possible
    $VM = New-VM -Name $VMName -Generation 2 -MemoryStartupBytes $MemoryStartupBytes -NewVHDPath $VhdxPath -NewVHDSizeBytes $VHDXSizeBytes -SwitchName $SwitchName 
    $VM | Set-VMProcessor -Count $ProcessorCount | Out-Null
    $VM | Get-VMIntegrationService -Name "Guest Service Interface" | Enable-VMIntegrationService | Out-Null

    $VM | Add-VMDvdDrive -Path $IsoPath | Out-Null
    $BootOrder = $(Get-VMDvdDrive -VMName $VMName), $(Get-VMHardDiskDrive -VMName $VMName)
    Set-VMFirmware -VMName $VMName -BootOrder $BootOrder 
    Set-VMKeyProtector -VMName $VMName -NewLocalKeyProtector 
    Enable-VMTPM -VMName $VMName 
    Set-VMFirmware -VMName $VMName -SecureBootTemplateId ([guid]'1734c6e8-3154-4dda-ba5f-a874cc483422') 

    # Disable Automatic Checkpoints
    $VM | Set-VM -AutomaticCheckpointsEnabled $false | Out-Null
}
catch {
    Write-Error "An error occurred: $_"
    if ($VM) {
        Remove-VM -Name $VMName -Force
    }
}