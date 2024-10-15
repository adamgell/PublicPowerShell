#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "ISO")]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$IsoPath,
    
    [Parameter(Mandatory = $true, ParameterSetName = "ParentVHD")]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$ParentVHDPath,
    
    [Parameter(Mandatory = $true)]
    [string]$VMNamePrefix,
    
    [uint64]$VHDXSizeBytes = 120GB,
    [int64]$MemoryStartupBytes = 4GB,
    [int64]$ProcessorCount = 2,
    [string]$SwitchName = "Default Switch",
    [string]$VirtualHardDiskPath = $null
)

$ErrorActionPreference = 'Stop'

function Write-StepOutput {
    param(
        [string]$StepName,
        [string]$StepDescription
    )
    Write-Host "`n[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $StepName" -ForegroundColor Cyan
    Write-Host $StepDescription
}

try {
    Write-StepOutput "Script Start" "Starting VM creation process"

    Write-StepOutput "Get VM Host" "Retrieving VM Host information"
    $VMHost = Get-VMHost
    if (-not $VirtualHardDiskPath) {
        $VirtualHardDiskPath = $VMHost.VirtualHardDiskPath
    }
    Write-Host "Virtual Hard Disk Path: $VirtualHardDiskPath"

    $PathAdd = New-Guid
    $TruncatedGuid = $PathAdd.ToString().Substring(0, 8)
    $NewVMName = "${VMNamePrefix}${TruncatedGuid}"
    $VhdxPath = Join-Path $VirtualHardDiskPath "$NewVMName.vhdx"
    Write-Host "VHDX Path: $VhdxPath"
    Write-Host "New VM Name: $NewVMName"

    if ($PSCmdlet.ParameterSetName -eq "ParentVHD") {
        Write-StepOutput "Create Differencing Disk" "Creating differencing disk based on parent VHD"
        New-VHD -Path $VhdxPath -ParentPath $ParentVHDPath -Differencing | Out-Null
        Write-Host "Differencing disk created successfully"

        Write-StepOutput "Create VM" "Creating new VM: $NewVMName with existing VHDX"
        $VM = New-VM -Name $NewVMName -Generation 2 -MemoryStartupBytes $MemoryStartupBytes -VHDPath $VhdxPath -SwitchName $SwitchName
    }
    else {
        Write-StepOutput "Create VM" "Creating new VM: $NewVMName"
        $VM = New-VM -Name $NewVMName -Generation 2 -MemoryStartupBytes $MemoryStartupBytes -NewVHDPath $VhdxPath -NewVHDSizeBytes $VHDXSizeBytes -SwitchName $SwitchName
    }
    Write-Host "VM created successfully"

    Write-StepOutput "Configure VM Processor" "Setting processor count to $ProcessorCount"
    $VM | Set-VMProcessor -Count $ProcessorCount | Out-Null
    Write-Host "Processor configuration completed"

    Write-StepOutput "Enable Integration Service" "Enabling Guest Service Interface"
    $VM | Get-VMIntegrationService -Name "Guest Service Interface" | Enable-VMIntegrationService | Out-Null
    Write-Host "Guest Service Interface enabled"

    if ($PSCmdlet.ParameterSetName -eq "ISO") {
        Write-StepOutput "Add DVD Drive" "Adding DVD drive with ISO: $IsoPath"
        $VM | Add-VMDvdDrive -Path $IsoPath | Out-Null
        Write-Host "DVD drive added successfully"

        Write-StepOutput "Set Boot Order" "Configuring boot order"
        $BootOrder = $(Get-VMDvdDrive -VMName $NewVMName), $(Get-VMHardDiskDrive -VMName $NewVMName)
        Set-VMFirmware -VMName $NewVMName -BootOrder $BootOrder 
        Write-Host "Boot order set: DVD Drive, Hard Disk"
    }
    else {
        Write-StepOutput "Set Boot Order" "Configuring boot order for VHD-based VM"
        $BootOrder = $(Get-VMHardDiskDrive -VMName $NewVMName)
        Set-VMFirmware -VMName $NewVMName -BootOrder $BootOrder 
        Write-Host "Boot order set: Hard Disk"
    }

    Write-StepOutput "Configure Security" "Setting up security features"
    Set-VMKeyProtector -VMName $NewVMName -NewLocalKeyProtector 
    Enable-VMTPM -VMName $NewVMName 
    Set-VMFirmware -VMName $NewVMName -SecureBootTemplateId ([guid]'1734c6e8-3154-4dda-ba5f-a874cc483422') 
    Write-Host "Security features configured: Key Protector, TPM, and Secure Boot"

    Write-StepOutput "Disable Automatic Checkpoints" "Turning off automatic checkpoints"
    $VM | Set-VM -AutomaticCheckpointsEnabled $false | Out-Null
    Write-Host "Automatic checkpoints disabled"

    Write-StepOutput "VM Creation Complete" "VM $NewVMName has been successfully created and configured"
    Write-Host "Summary:"
    Write-Host "  - Name: $NewVMName"
    Write-Host "  - Memory: $($MemoryStartupBytes / 1GB) GB"
    Write-Host "  - Processors: $ProcessorCount"
    Write-Host "  - VHDX Path: $VhdxPath"
    Write-Host "  - Switch: $SwitchName"
    if ($PSCmdlet.ParameterSetName -eq "ISO") {
        Write-Host "  - ISO Path: $IsoPath"
    }
    else {
        Write-Host "  - Parent VHD Path: $ParentVHDPath"
    }
}
catch {
    Write-StepOutput "Error Occurred" "An error occurred during VM creation"
    Write-Error "Error details: $_"
    if ($VM) {
        Write-Host "Attempting to remove partially created VM..." -ForegroundColor Yellow
        Remove-VM -Name $NewVMName -Force
        Write-Host "Partially created VM removed." -ForegroundColor Yellow
    }
}