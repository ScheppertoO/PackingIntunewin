@echo off
echo =======================================
echo   IntuneWin App Packaging Tool
echo =======================================
echo.
echo Starting launcher with execution policy bypass...
echo.

REM Change to script directory
cd /d "%~dp0"

REM Start PowerShell with bypassed execution policy
powershell.exe -ExecutionPolicy Bypass -File "%~dp0Start-IntuneWinTool.ps1"

echo.
echo Script finished. Press any key to exit...
pause >nul
