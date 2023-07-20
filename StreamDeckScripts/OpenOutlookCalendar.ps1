Param(
    [string] $proc = "OUTLOOK",
    [string] $adm
)
Clear-Host

Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class WinAp {
      [DllImport("user32.dll")]
      [return: MarshalAs(UnmanagedType.Bool)]
      public static extern bool SetForegroundWindow(IntPtr hWnd);

      [DllImport("user32.dll")]
      [return: MarshalAs(UnmanagedType.Bool)]
      public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    }
"@
$p = Get-Process | Where-Object { $_.mainWindowTitle } | Where-Object { $_.Name -like "$proc" }
if (($null -eq $p) -and ($adm -ne "")) {
    Start-Process "$proc" -Verb runAs -ArgumentList "/select outlook:calendar"
}
elseif (($null -eq $p) -and ($adm -eq "")) {
    Start-Process "$proc" -ArgumentList "/select outlook:calendar"
}
else {
    $h = $p.MainWindowHandle
    [void] [WinAp]::SetForegroundWindow($h)
    [void] [WinAp]::ShowWindow($h, 3)
} 