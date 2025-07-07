# IntuneWin App Packaging Tool - Launcher
# This script allows you to choose between German and English GUI

# Set execution policy for current session only (for unsigned scripts)
Write-Host "Setting execution policy for current session..." -ForegroundColor Yellow
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

$ScriptPath = $PSScriptRoot

# Display language selection menu
Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "   IntuneWin App Packaging Tool" -ForegroundColor White
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Please select your preferred language:" -ForegroundColor White
Write-Host ""
Write-Host "[1] Deutsch (German)" -ForegroundColor Green
Write-Host "[2] English" -ForegroundColor Green
Write-Host "[Q] Quit / Beenden" -ForegroundColor Red
Write-Host ""

do {
    $choice = Read-Host "Enter your choice (1/2/Q)"
    
    switch ($choice.ToUpper()) {
        "1" {
            Write-Host ""
            Write-Host "Starting German GUI..." -ForegroundColor Green
            $GermanScript = Join-Path $ScriptPath "scripts\German_GUI_WPF.ps1"
            if (Test-Path $GermanScript) {
                & $GermanScript
            } else {
                Write-Host "Error: German_GUI_WPF.ps1 not found!" -ForegroundColor Red
                Write-Host "Please ensure the file exists in: $GermanScript" -ForegroundColor Red
            }
            $validChoice = $true
        }
        "2" {
            Write-Host ""
            Write-Host "Starting English GUI..." -ForegroundColor Green
            $EnglishScript = Join-Path $ScriptPath "scripts\ENG_GUI_WPF.ps1"
            if (Test-Path $EnglishScript) {
                & $EnglishScript
            } else {
                Write-Host "Error: ENG_GUI_WPF.ps1 not found!" -ForegroundColor Red
                Write-Host "Please ensure the file exists in: $EnglishScript" -ForegroundColor Red
            }
            $validChoice = $true
        }
        "Q" {
            Write-Host ""
            Write-Host "Exiting... / Beenden..." -ForegroundColor Yellow
            $validChoice = $true
        }
        default {
            Write-Host "Invalid choice. Please enter 1, 2, or Q" -ForegroundColor Red
            Write-Host "Ungueltige Auswahl. Bitte 1, 2 oder Q eingeben" -ForegroundColor Red
            $validChoice = $false
        }
    }
} while (-not $validChoice)

Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
Write-Host "Druecke eine beliebige Taste zum Beenden..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
