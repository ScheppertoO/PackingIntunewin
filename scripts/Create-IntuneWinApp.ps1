# Interaktive Abfrage des Input-Pfades
$BaseInputPath = "C:\Packaging\Input"
$BaseOutputPath = "C:\Packaging\Output"
$IntuneTool = "C:\Tools\IntuneWinAppUtil.exe"

# Hilfsfunktionen
function Get-UninstallInfo {
    param(
        [string]$AppName,
        [string]$ExePath
    )
    
    Write-Host "🔍 Suche nach Deinstallationsinformationen für '$AppName'..." -ForegroundColor Yellow
    
    # Registry-Pfade für installierte Programme
    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($Path in $RegistryPaths) {
        try {
            $Programs = Get-ItemProperty $Path -ErrorAction SilentlyContinue | Where-Object {
                $_.DisplayName -like "*$AppName*" -or 
                $_.InstallLocation -like "*$([System.IO.Path]::GetDirectoryName($ExePath))*"
            }
            
            foreach ($Program in $Programs) {
                if ($Program.UninstallString) {
                    Write-Host "✅ Gefunden: $($Program.DisplayName)" -ForegroundColor Green
                    return @{
                        Found = $true
                        UninstallString = $Program.UninstallString
                        QuietUninstallString = $Program.QuietUninstallString
                        DisplayName = $Program.DisplayName
                    }
                }
            }
        }
        catch {
            # Ignoriere Registry-Fehler
        }
    }
    
    return @{ Found = $false }
}

function Test-ExeUninstallParameters {
    param([string]$ExePath)
    
    Write-Host "🧪 Teste Deinstallationsparameter für EXE..." -ForegroundColor Yellow
    
    # Häufige Deinstallationsparameter testen
    $CommonParams = @("/uninstall", "/remove", "/u", "-uninstall", "-remove", "-u", "/x")
    $SilentParams = @("/silent", "/quiet", "/s", "/q", "-silent", "-quiet", "-s", "-q")
    
    foreach ($UninstallParam in $CommonParams) {
        foreach ($SilentParam in $SilentParams) {
            $TestCommand = "$ExePath $UninstallParam $SilentParam /?"
            try {
                $Result = Start-Process -FilePath $ExePath -ArgumentList "$UninstallParam", "$SilentParam", "/?" -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
                if ($Result.ExitCode -eq 0) {
                    Write-Host "✅ Mögliche Parameter gefunden: $UninstallParam $SilentParam" -ForegroundColor Green
                    return "$UninstallParam $SilentParam"
                }
            }
            catch {
                # Parameter nicht unterstützt
            }
        }
    }
    
    # Fallback: Standard-Parameter
    Write-Host "⚠️ Keine spezifischen Parameter gefunden, verwende Standard" -ForegroundColor Yellow
    return "/uninstall /silent"
}

# Auswahl oder Eingabe eines Unterordners
$InputFolder = Read-Host "Gib den Namen des Unterordners ein (unter '$BaseInputPath')"
$SourceFolder = Join-Path $BaseInputPath $InputFolder
$OutputFolder = Join-Path $BaseOutputPath $InputFolder

# Prüfen, ob eine .exe vorhanden ist
$ExeFiles = Get-ChildItem -Path $SourceFolder -Filter *.exe
if ($ExeFiles.Count -ne 1) {
    Write-Host "❌ Es muss genau eine .exe im Verzeichnis '$SourceFolder' liegen!" -ForegroundColor Red
    exit 1
}

$ExeName = $ExeFiles[0].Name
$ExePath = $ExeFiles[0].FullName
$AppName = [System.IO.Path]::GetFileNameWithoutExtension($ExeName)

# Rückfrage, ob ein Neustart nach der Installation erforderlich ist
$RebootRequired = Read-Host "Erfordert die Installation einen Neustart? (j/n)"
if ($RebootRequired -eq 'j') {
    $ExitCode = 3010  # Soft reboot required
} else {
    $ExitCode = 0     # Normaler Erfolg
}

# Deinstallationsinformationen ermitteln
Write-Host "`n🔧 Ermittle Deinstallationsinformationen..." -ForegroundColor Cyan

# Erst Registry durchsuchen
$UninstallInfo = Get-UninstallInfo -AppName $AppName -ExePath $ExePath

$UninstallCommand = ""
if ($UninstallInfo.Found) {
    Write-Host "✅ Registry-Eintrag gefunden!" -ForegroundColor Green
    
    if ($UninstallInfo.QuietUninstallString) {
        $UninstallCommand = $UninstallInfo.QuietUninstallString
        Write-Host "📝 Verwende QuietUninstallString: $UninstallCommand" -ForegroundColor Green
    } else {
        # Versuche, /quiet oder /silent zur UninstallString hinzuzufügen
        $UninstallString = $UninstallInfo.UninstallString
        if ($UninstallString -notmatch "/quiet|/silent|-quiet|-silent") {
            if ($UninstallString -like "*msiexec*") {
                $UninstallCommand = "$UninstallString /quiet"
            } else {
                $UninstallCommand = "$UninstallString /silent"
            }
        } else {
            $UninstallCommand = $UninstallString
        }
        Write-Host "📝 Verwende modifizierte UninstallString: $UninstallCommand" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ Kein Registry-Eintrag gefunden, teste EXE-Parameter..." -ForegroundColor Yellow
    $UninstallParams = Test-ExeUninstallParameters -ExePath $ExePath
    $UninstallCommand = "$ExeName $UninstallParams"
    Write-Host "📝 Verwende EXE mit Parametern: $UninstallCommand" -ForegroundColor Yellow
}

# Ausgabe
Write-Host "`n📋 Zusammenfassung:" -ForegroundColor Cyan
Write-Host "✅ Gefundene EXE: $ExeName"
Write-Host "📦 App-Name wird gesetzt auf: $AppName"
Write-Host "🔁 Exit-Code wird auf $ExitCode gesetzt"
Write-Host "🗑️ Deinstallation: $UninstallCommand"

# Ausgabeordner vorbereiten
New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null

# install.cmd dynamisch erstellen
$InstallCmd = @"
@echo off
echo Installing $AppName...
$ExeName /silent
if %errorlevel% neq 0 (
    echo Installation failed with exit code %errorlevel%
    exit /b %errorlevel%
)
echo Installation completed successfully
exit /b $ExitCode
"@
Set-Content -Path "$SourceFolder\install.cmd" -Value $InstallCmd -Encoding ASCII

# uninstall.cmd dynamisch erstellen
$UninstallCmd = @"
@echo off
echo Uninstalling $AppName...
$UninstallCommand
if %errorlevel% neq 0 (
    echo Uninstallation failed with exit code %errorlevel%
    exit /b %errorlevel%
)
echo Uninstallation completed successfully
exit /b 0
"@
Set-Content -Path "$SourceFolder\uninstall.cmd" -Value $UninstallCmd -Encoding ASCII

Write-Host "`n📝 Erstelle Batch-Dateien..." -ForegroundColor Cyan
Write-Host "✅ install.cmd erstellt"
Write-Host "✅ uninstall.cmd erstellt"

# .intunewin erstellen
Write-Host "`n📦 Erstelle .intunewin Paket..." -ForegroundColor Cyan
& $IntuneTool -c $SourceFolder -s "install.cmd" -o $OutputFolder

# Prüfen ob .intunewin erfolgreich erstellt wurde
$IntunewinFile = Get-ChildItem -Path $OutputFolder -Filter "*.intunewin" | Select-Object -First 1
if ($IntunewinFile) {
    Write-Host "✅ .intunewin Paket erfolgreich erstellt: $($IntunewinFile.Name)" -ForegroundColor Green
} else {
    Write-Host "❌ Fehler beim Erstellen des .intunewin Pakets!" -ForegroundColor Red
}

# Metadaten schreiben
$Meta = @{
    AppName = $AppName
    Installer = $ExeName
    InstallCommand = "install.cmd"
    UninstallCommand = "uninstall.cmd"
    UninstallMethod = if ($UninstallInfo.Found) { "Registry" } else { "EXE Parameters" }
    UninstallString = $UninstallCommand
    ExitCode = $ExitCode
    RebootRequired = ($ExitCode -eq 3010)
    DetectionType = "Registry (manuell konfigurieren)"
    CreatedOn = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    CreatedBy = $env:USERNAME
}
$Meta | ConvertTo-Json -Depth 3 | Set-Content -Path "$OutputFolder\metadata.json"

Write-Host "`n📄 Metadaten gespeichert in: $OutputFolder\metadata.json" -ForegroundColor Green
Write-Host "`n🎉 Verpackung abgeschlossen!" -ForegroundColor Green
Write-Host "📁 Ausgabeordner: $OutputFolder" -ForegroundColor Yellow

# Ausgabe der wichtigsten Informationen für Intune
Write-Host "`n📋 Informationen für Microsoft Intune:" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "App-Name: $AppName"
Write-Host "Install-Befehl: install.cmd"
Write-Host "Uninstall-Befehl: uninstall.cmd"
Write-Host "Rückgabecodes: 0 (Erfolg)" + $(if ($ExitCode -eq 3010) { ", 3010 (Neustart erforderlich)" } else { "" })
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
