# IntuneWinAppUtil.exe Installation Guide

## Manual Installation Required

The automatic download of IntuneWinAppUtil.exe is currently not working due to Microsoft's restrictions. Please follow these steps to manually install the tool:

## Option 1: Microsoft Download (Recommended)

1. Visit: https://aka.ms/win32contentpreptool
2. Download the latest version of Microsoft Win32 Content Prep Tool
3. Save the `IntuneWinAppUtil.exe` file to: `tools\IntuneWinAppUtil.exe`

## Option 2: Intune Admin Center (Most Reliable)

1. Go to https://endpoint.microsoft.com
2. Navigate to: Apps > Windows > Add > Win32 app  
3. Click on "Select app package file"
4. Download the preparation tool from there
5. Save as `tools\IntuneWinAppUtil.exe`

## Option 3: GitHub Repository

1. Visit: https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool
2. Go to the "Releases" section
3. Download the latest release
4. Extract and find `IntuneWinAppUtil.exe`
5. Place in `tools\` folder

## Option 4: PowerShell Gallery

```powershell
# Search for community modules
Find-Module -Name "*Intune*" | Where-Object { $_.Description -like "*Win32*" }
```

## Option 5: Chocolatey

```cmd
# If Chocolatey is installed
choco search intunewinapputil
```

## Verification Steps

After placing the file in the `tools\` folder:

1. **File Size Check**: Should be around 50-60 KB (files under 20KB are corrupted)
2. **Function Test**: 
   ```powershell
   .\tools\IntuneWinAppUtil.exe /?
   ```
3. **Run GUI**: The tool will automatically detect and validate the file

## File Location

The tool should be placed at:
```
PackingIntunewin\
├── tools\
│   └── IntuneWinAppUtil.exe  ← Place file here
├── scripts\
│   ├── German_GUI_WPF.ps1
│   └── ENG_GUI_WPF.ps1
└── Start-IntuneWinTool.ps1
```

## Troubleshooting

### Common Issues:
- **Antivirus blocking**: Add `tools\` folder to exceptions
- **Network restrictions**: Try downloading from different network
- **File corruption**: Re-download if file is under 100KB

### Diagnostic Command:
```powershell
.\scripts\Diagnose-IntuneWinTool.ps1
```

## Alternative: Use Existing Installation

If you already have IntuneWinAppUtil.exe installed elsewhere on your system, you can copy it to the `tools\` folder.

---
**Updated:** December 2024 - Compatible with tool version 1.8.6+
