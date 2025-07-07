# IntuneWinAppUtil.exe Installation Guide

## Manual Installation Required

The automatic download of IntuneWinAppUtil.exe is currently not working due to Microsoft's restrictions. Please follow these steps to manually install the tool:

## Option 1: Microsoft Download (Recommended)

1. Visit: https://aka.ms/win32contentpreptool
2. Download the latest version of Microsoft Win32 Content Prep Tool
3. Save the `IntuneWinAppUtil.exe` file to: `tools\IntuneWinAppUtil.exe`

## Option 2: Intune Admin Center

1. Go to https://endpoint.microsoft.com
2. Navigate to: Apps > Windows > Add > Win32 app  
3. Click on "Select app package file"
4. Download the preparation tool from there
5. Save as `tools\IntuneWinAppUtil.exe`

## Option 3: PowerShell Gallery

```powershell
# Search for community modules
Find-Module -Name "*Intune*" | Where-Object { $_.Description -like "*Win32*" }
```

## Option 4: Chocolatey

```cmd
# If Chocolatey is installed
choco search intunewinapputil
```

## Verification

After placing the file in the `tools\` folder, run the GUI again. The tool should detect and validate the file automatically.

## File Location

The tool should be placed at:
```
PackingIntunewin\
├── tools\
│   └── IntuneWinAppUtil.exe  ← Place file here
├── scripts\
└── Start-IntuneWinTool.ps1
```

## Alternative: Use Existing Installation

If you already have IntuneWinAppUtil.exe installed elsewhere on your system, you can copy it to the `tools\` folder.
