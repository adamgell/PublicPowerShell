# Packaging and Deploying Citrix Shortcut with Intune

## Prerequisites
- Microsoft Win32 Content Prep Tool
- Access to Microsoft Intune admin portal
- PowerShell scripts (CreateShortcut.ps1 and Detect.ps1)

## Packaging Steps
1. Create folder structure:
```
CitrixShortcut/
├── CreateShortcut.ps1
└── Detect.ps1
```

2. Run Content Prep Tool:
```powershell
IntuneWinAppUtil.exe -c "CitrixShortcut" -s "CreateShortcut.ps1" -o "Output"
```

## Intune Configuration

### Basic Information
- Name: Citrix Workspace Shortcut
- Description: Creates Citrix Workspace shortcut on Public Desktop
- Publisher: Your Organization

### Program Settings
```
Install command: powershell.exe -executionpolicy bypass -file CreateShortcut.ps1
Uninstall command: cmd.exe /c del "C:\Users\Public\Desktop\CitrixWorkspace.lnk"
    Or the right LNK file. 
Install behavior: System
Device restart: No
```

### Requirements
- Windows 10 (1607+)
- Architecture: 32-bit and 64-bit
- Minimum disk space: 1MB

### Detection Rules
1. Select "Use custom script"
2. Upload Detection.ps1
3. Make sure you use the right detection script for the shortcut that you are uploading.
