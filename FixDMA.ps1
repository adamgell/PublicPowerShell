<#
.SYNOPSIS 
 Give ownership of a file or folder to the specified user.

.DESCRIPTION
 Give the current process the SeTakeOwnershipPrivilege" and "SeRestorePrivilege" rights which allows it
 to reset ownership of an object.  The script will then set the owner to be the specified user.

.PARAMETER Path (Required)
 The path to the object on which you wish to change ownership.  It can be a file or a folder.

.PARAMETER User (Required)
 The user whom you want to be the owner of the specified object.  The user should be in the format
 <domain>\<username>.  Other user formats will not work.  For system accounts, such as System, the user
 should be specified as "NT AUTHORITY\System".  If the domain is missing, the local machine will be assumed.

.PARAMETER Recurse (switch)
 Causes the function to parse through the Path recursively.

.INPUTS
 None. You cannot pipe objects to Take-Ownership

.OUTPUTS
 None

.NOTES
 Name:    Take-Ownership.ps1
 Author:  Jason Eberhardt
 Date:    2017-07-20
#>
function Take-Ownership {
    [CmdletBinding(SupportsShouldProcess = $false)]
    Param([Parameter(Mandatory = $true, ValueFromPipeline = $false)] [ValidateNotNullOrEmpty()] [string]$Path,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false)] [ValidateNotNullOrEmpty()] [string]$User,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false)] [switch]$Recurse)

    Begin {
        $AdjustTokenPrivileges = @"
using System;
using System.Runtime.InteropServices;

  public class TokenManipulator {
    [DllImport("kernel32.dll", ExactSpelling = true)]
      internal static extern IntPtr GetCurrentProcess();

    [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
      internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall, ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
    [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
      internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
    [DllImport("advapi32.dll", SetLastError = true)]
      internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    internal struct TokPriv1Luid {
      public int Count;
      public long Luid;
      public int Attr;
    }

    internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
    internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
    internal const int TOKEN_QUERY = 0x00000008;
    internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;

    public static bool AddPrivilege(string privilege) {
      bool retVal;
      TokPriv1Luid tp;
      IntPtr hproc = GetCurrentProcess();
      IntPtr htok = IntPtr.Zero;
      retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
      tp.Count = 1;
      tp.Luid = 0;
      tp.Attr = SE_PRIVILEGE_ENABLED;
      retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
      retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
      return retVal;
    }

    public static bool RemovePrivilege(string privilege) {
      bool retVal;
      TokPriv1Luid tp;
      IntPtr hproc = GetCurrentProcess();
      IntPtr htok = IntPtr.Zero;
      retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
      tp.Count = 1;
      tp.Luid = 0;
      tp.Attr = SE_PRIVILEGE_DISABLED;
      retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
      retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
      return retVal;
    }
  }
"@
    }

    Process {
        $Item = Get-Item $Path
        Write-Verbose "Giving current process token ownership rights"
        Add-Type $AdjustTokenPrivileges -PassThru > $null
        [void][TokenManipulator]::AddPrivilege("SeTakeOwnershipPrivilege") 
        [void][TokenManipulator]::AddPrivilege("SeRestorePrivilege") 

        # Change ownership
        $Account = $User.Split("\")
        if ($Account.Count -eq 1) { $Account += $Account[0]; $Account[0] = $env:COMPUTERNAME }
        $Owner = New-Object System.Security.Principal.NTAccount($Account[0], $Account[1])
        Write-Verbose "Change ownership to '$($Account[0])\$($Account[1])'"

        $Provider = $Item.PSProvider.Name
        if ($Item.PSIsContainer) {
            switch ($Provider) {
                "FileSystem" { $ACL = [System.Security.AccessControl.DirectorySecurity]::new() }
                "Registry" {
                    $ACL = [System.Security.AccessControl.RegistrySecurity]::new()
                    # Get-Item doesn't open the registry in a way that we can write to it.
                    switch ($Item.Name.Split("\")[0]) {
                        "HKEY_CLASSES_ROOT" { $rootKey = [Microsoft.Win32.Registry]::ClassesRoot; break }
                        "HKEY_LOCAL_MACHINE" { $rootKey = [Microsoft.Win32.Registry]::LocalMachine; break }
                        "HKEY_CURRENT_USER" { $rootKey = [Microsoft.Win32.Registry]::CurrentUser; break }
                        "HKEY_USERS" { $rootKey = [Microsoft.Win32.Registry]::Users; break }
                        "HKEY_CURRENT_CONFIG" { $rootKey = [Microsoft.Win32.Registry]::CurrentConfig; break }
                    }
                    $Key = $Item.Name.Replace(($Item.Name.Split("\")[0] + "\"), "")
                    $Item = $rootKey.OpenSubKey($Key, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::TakeOwnership) 
                }
                default { throw "Unknown provider:  $($Item.PSProvider.Name)" }
            }
            $ACL.SetOwner($Owner)
            Write-Verbose "Setting owner on $Path"
            $Item.SetAccessControl($ACL)
            if ($Provider -eq "Registry") { $Item.Close() }

            if ($Recurse.IsPresent) {
                # You can't set ownership on Registry Values
                if ($Provider -eq "Registry") { $Items = Get-ChildItem -Path $Path -Recurse -Force | Where-Object { $_.PSIsContainer } }
                else { $Items = Get-ChildItem -Path $Path -Recurse -Force }
                $Items = @($Items)
                for ($i = 0; $i -lt $Items.Count; $i++) {
                    switch ($Provider) {
                        "FileSystem" {
                            $Item = Get-Item $Items[$i].FullName
                            if ($Item.PSIsContainer) { $ACL = [System.Security.AccessControl.DirectorySecurity]::new() }
                            else { $ACL = [System.Security.AccessControl.FileSecurity]::new() } 
                        }
                        "Registry" {
                            $Item = Get-Item $Items[$i].PSPath
                            $ACL = [System.Security.AccessControl.RegistrySecurity]::new()
                            # Get-Item doesn't open the registry in a way that we can write to it.
                            switch ($Item.Name.Split("\")[0]) {
                                "HKEY_CLASSES_ROOT" { $rootKey = [Microsoft.Win32.Registry]::ClassesRoot; break }
                                "HKEY_LOCAL_MACHINE" { $rootKey = [Microsoft.Win32.Registry]::LocalMachine; break }
                                "HKEY_CURRENT_USER" { $rootKey = [Microsoft.Win32.Registry]::CurrentUser; break }
                                "HKEY_USERS" { $rootKey = [Microsoft.Win32.Registry]::Users; break }
                                "HKEY_CURRENT_CONFIG" { $rootKey = [Microsoft.Win32.Registry]::CurrentConfig; break }
                            }
                            $Key = $Item.Name.Replace(($Item.Name.Split("\")[0] + "\"), "")
                            $Item = $rootKey.OpenSubKey($Key, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::TakeOwnership) 
                        }
                        default { throw "Unknown provider:  $($Item.PSProvider.Name)" }
                    }
                    $ACL.SetOwner($Owner)
                    Write-Verbose "Setting owner on $($Item.Name)"
                    $Item.SetAccessControl($ACL)
                    if ($Provider -eq "Registry") { $Item.Close() }
                }
            } # Recursion
        }
        else {
            if ($Recurse.IsPresent) { Write-Warning "Object specified is neither a folder nor a registry key.  Recursion is not possible." }
            switch ($Provider) {
                "FileSystem" { $ACL = [System.Security.AccessControl.FileSecurity]::new() }
                "Registry" { throw "You cannot set ownership on a registry value" }
                default { throw "Unknown provider:  $($Item.PSProvider.Name)" }
            }
            $ACL.SetOwner($Owner)
            Write-Verbose "Setting owner on $Path"
            $Item.SetAccessControl($ACL)
        }
    }
}

Take-Ownership -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\DmaSecurity\AllowedBuses" -User $env:USERNAME -Recurse
#take ownership of key
<#
The following DMA (Direct Memory Access) capable devices are not declared as protected from external access, 
which can block security features such as BitLocker automatic device encryption:

The following DMA (Direct Memory Access) capable devices are not declared as protected from external access, 
which can block security features such as BitLocker automatic device encryption:


ISA Bridge:
	PCI\VEN_1022&DEV_790E (PCI standard ISA bridge)

PCI-to-PCI Bridge:
	PCI\VEN_1022&DEV_15DB (PCI Express Root Port)
	PCI\VEN_1022&DEV_15DC (PCI Express Root Port)
	PCI\VEN_1022&DEV_15D3 (PCI Express Root Port)
	PCI\VEN_1022&DEV_15D3 (PCI Express Root Port)
	PCI\VEN_1022&DEV_15D3 (PCI Express Root Port)
	PCI\VEN_1022&DEV_15D3 (PCI Express Root Port)
	PCI\VEN_1022&DEV_15D3 (PCI Express Root Port)


#>

#ensure path is created in registry
#this is a default path so it should be there but just in case
if ((Test-Path -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Control\DmaSecurity\AllowedBuses") -ne $true) { New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\DmaSecurity\AllowedBuses" -force}
#ISA Bridge:
New-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\DmaSecurity\AllowedBuses' -Name "Chipset Controller" -Value 'PCI\VEN_1022&DEV_790E'
#PCI-to-PCI Bridge:
New-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\DmaSecurity\AllowedBuses' -Name "PCI Express Root Port 1" -Value 'PCI\VEN_1022&DEV_15DB' -PropertyType String -Force
New-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\DmaSecurity\AllowedBuses' -Name "PCI Express Root Port 2" -Value 'PCI\VEN_1022&DEV_15DC' -PropertyType String -Force
New-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\DmaSecurity\AllowedBuses' -Name "PCI Express Root Port 3" -Value 'PCI\VEN_1022&DEV_15D3' -PropertyType String -Force
New-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\DmaSecurity\AllowedBuses' -Name "PCI Express Root Port 4" -Value 'PCI\VEN_1022&DEV_15D3' -PropertyType String -Force
New-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\DmaSecurity\AllowedBuses' -Name "PCI Express Root Port 5" -Value 'PCI\VEN_1022&DEV_15D3' -PropertyType String -Force
New-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\DmaSecurity\AllowedBuses' -Name "PCI Express Root Port 6" -Value 'PCI\VEN_1022&DEV_15D3' -PropertyType String -Force
New-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\DmaSecurity\AllowedBuses' -Name "PCI Express Root Port 7" -Value 'PCI\VEN_1022&DEV_15D3' -PropertyType String -Force