# Portable IntuneWin App Packaging Tool
# Arbeitet mit relativen Pfaden - unabhängig vom Speicherort

# Basis-Pfade relativ zum Skript-Ordner
$ScriptPath = $PSScriptRoot
$BaseInputPath = Join-Path $ScriptPath "apps"
$BaseOutputPath = Join-Path $ScriptPath "IntunewinApps"
$ToolsPath = Join-Path $ScriptPath "IntunewinApps\tools"
$IntuneTool = Join-Path $ToolsPath "IntuneWinAppUtil.exe"
$GitHubRepo = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool"

# Hilfsfunktionen
function Test-IntuneWinAppUtil {
    Write-Host "🔧 Prüfe IntuneWinAppUtil.exe..." -ForegroundColor Cyan
    
    # Tools-Ordner erstellen falls nicht vorhanden
    if (-not (Test-Path $ToolsPath)) {
        Write-Host "📁 Erstelle Tools-Ordner: $ToolsPath" -ForegroundColor Yellow
        New-Item -ItemType Directory -Force -Path $ToolsPath | Out-Null
    }
    
    # Prüfen ob IntuneWinAppUtil.exe vorhanden ist
    if (Test-Path $IntuneTool) {
        Write-Host "✅ IntuneWinAppUtil.exe gefunden: $IntuneTool" -ForegroundColor Green
        return $true
    }
    
    Write-Host "⚠️ IntuneWinAppUtil.exe nicht gefunden, lade von GitHub herunter..." -ForegroundColor Yellow
    
    try {
        # Versuche verschiedene Download-Methoden
        $Downloaded = $false
        
        # Methode 1: GitHub Releases API (für ZIP-Dateien)
        Write-Host "🌐 Suche nach der neuesten Version..." -ForegroundColor Yellow
        $ApiUrl = "https://api.github.com/repos/microsoft/Microsoft-Win32-Content-Prep-Tool/releases/latest"
        $Release = Invoke-RestMethod -Uri $ApiUrl -ErrorAction Stop
        
        # Suche nach ZIP-Dateien in den Assets
        $ZipAsset = $Release.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
        
        if ($ZipAsset) {
            Write-Host "📥 Gefunden: $($ZipAsset.name) (Version: $($Release.tag_name))" -ForegroundColor Green
            Write-Host "🔗 Download-URL: $($ZipAsset.browser_download_url)" -ForegroundColor Gray
            
            # Temporäres Verzeichnis für Download
            $TempZip = Join-Path $env:TEMP "IntuneWinAppUtil.zip"
            $TempExtract = Join-Path $env:TEMP "IntuneWinAppUtil_Extract"
            
            # ZIP-Datei herunterladen
            $WebClient = New-Object System.Net.WebClient
            $WebClient.DownloadFile($ZipAsset.browser_download_url, $TempZip)
            
            # ZIP extrahieren
            if (Test-Path $TempExtract) {
                Remove-Item $TempExtract -Recurse -Force
            }
            Expand-Archive -Path $TempZip -DestinationPath $TempExtract -Force
            
            # IntuneWinAppUtil.exe suchen
            $ExeFile = Get-ChildItem -Path $TempExtract -Filter "IntuneWinAppUtil.exe" -Recurse | Select-Object -First 1
            
            if ($ExeFile) {
                Copy-Item $ExeFile.FullName $IntuneTool -Force
                Write-Host "✅ IntuneWinAppUtil.exe erfolgreich extrahiert!" -ForegroundColor Green
                $Downloaded = $true
            }
            
            # Aufräumen
            if (Test-Path $TempZip) { Remove-Item $TempZip -Force }
            if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force }
        }
        
        # Methode 2: Direkte URLs (Fallback)
        if (-not $Downloaded) {
            Write-Host "⚠️ Kein ZIP in Release gefunden, versuche direkte Download-URLs..." -ForegroundColor Yellow
            
            # Bekannte direkte URLs (basierend auf Version 1.8.6)
            $DirectUrls = @(
                "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/releases/download/v1.8.6/IntuneWinAppUtil.exe",
                "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/releases/latest/download/IntuneWinAppUtil.exe"
            )
            
            foreach ($Url in $DirectUrls) {
                try {
                    Write-Host "  Versuche: $Url" -ForegroundColor Gray
                    $WebClient = New-Object System.Net.WebClient
                    $WebClient.DownloadFile($Url, $IntuneTool)
                    
                    if (Test-Path $IntuneTool) {
                        Write-Host "✅ Download erfolgreich!" -ForegroundColor Green
                        $Downloaded = $true
                        break
                    }
                } catch {
                    Write-Host "❌ URL fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
        
        # Methode 3: Repo-Clone (letzte Option)
        if (-not $Downloaded) {
            Write-Host "⚠️ Versuche Repository-basierte Lösung..." -ForegroundColor Yellow
            
            # GitHub Raw-Links zu bekannten Builds versuchen
            $RawUrls = @(
                "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/main/IntuneWinAppUtil.exe",
                "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/v1.8.6/IntuneWinAppUtil.exe"
            )
            
            foreach ($Url in $RawUrls) {
                try {
                    Write-Host "🔄 Versuche Raw-URL: $Url" -ForegroundColor Gray
                    $WebClient = New-Object System.Net.WebClient
                    $WebClient.DownloadFile($Url, $IntuneTool)
                    
                    if (Test-Path $IntuneTool) {
                        Write-Host "✅ Download erfolgreich!" -ForegroundColor Green
                        $Downloaded = $true
                        break
                    }
                } catch {
                    Write-Host "❌ Raw-URL fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
        
        # Erfolg prüfen
        if ($Downloaded -and (Test-Path $IntuneTool)) {
            $FileInfo = Get-Item $IntuneTool
            Write-Host "✅ Download erfolgreich! Dateigröße: $([math]::Round($FileInfo.Length / 1MB, 2)) MB" -ForegroundColor Green
            
            # Versuche Version zu ermitteln
            try {
                $VersionInfo = & $IntuneTool -v 2>$null
                if ($VersionInfo) {
                    Write-Host "📋 Tool-Version: $VersionInfo" -ForegroundColor Green
                }
            } catch {
                # Version-Check optional
            }
            
            return $true
        } else {
            Write-Host "❌ Alle Download-Methoden fehlgeschlagen!" -ForegroundColor Red
            return $false
        }
        
    } catch {
        Write-Host "❌ Fehler beim Download: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "🌐 Bitte besuchen Sie manuell: $GitHubRepo" -ForegroundColor Yellow
        Write-Host "📥 Laden Sie IntuneWinAppUtil.exe herunter und speichern Sie es unter: $IntuneTool" -ForegroundColor Yellow
        return $false
    }
}

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

function Initialize-Folders {
    Write-Host "📁 Initialisiere Ordnerstruktur..." -ForegroundColor Cyan
    
    # Benötigte Ordner erstellen
    $RequiredFolders = @($BaseInputPath, $BaseOutputPath, $ToolsPath)
    
    foreach ($Folder in $RequiredFolders) {
        if (-not (Test-Path $Folder)) {
            Write-Host "   Erstelle: $($Folder -replace [regex]::Escape($ScriptPath), '.')" -ForegroundColor Yellow
            New-Item -ItemType Directory -Force -Path $Folder | Out-Null
        }
    }
    
    Write-Host "✅ Ordnerstruktur bereit" -ForegroundColor Green
    Write-Host "   📂 Apps: $(Split-Path $BaseInputPath -Leaf)" -ForegroundColor Gray
    Write-Host "   📦 Output: $(Split-Path $BaseOutputPath -Leaf)" -ForegroundColor Gray
    Write-Host "   🔧 Tools: $(Split-Path $ToolsPath -Leaf)" -ForegroundColor Gray
}

# Tool-Verfügbarkeit prüfen
Write-Host "🚀 Starte Portable IntuneWin App Packaging Tool" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📍 Arbeitsverzeichnis: $ScriptPath" -ForegroundColor Gray

# Ordnerstruktur initialisieren
Initialize-Folders

if (-not (Test-IntuneWinAppUtil)) {
    Write-Host "❌ IntuneWinAppUtil.exe konnte nicht bereitgestellt werden!" -ForegroundColor Red
    Write-Host "📋 Mögliche Lösungen:" -ForegroundColor Yellow
    Write-Host "   1. Internetverbindung prüfen" -ForegroundColor Yellow
    Write-Host "   2. Manuell von $GitHubRepo herunterladen" -ForegroundColor Yellow
    Write-Host "   3. Tool unter $(Split-Path $IntuneTool -Leaf) speichern" -ForegroundColor Yellow
    exit 1
}

# Verfügbare Apps anzeigen
Write-Host "`n📋 Verfügbare Apps im 'apps' Ordner:" -ForegroundColor Cyan
$AvailableApps = Get-ChildItem -Path $BaseInputPath -Directory -ErrorAction SilentlyContinue | Sort-Object Name
if ($AvailableApps.Count -gt 0) {
    foreach ($App in $AvailableApps) {
        $ExeCount = (Get-ChildItem -Path $App.FullName -Filter "*.exe" -ErrorAction SilentlyContinue).Count
        $Status = if ($ExeCount -eq 1) { "✅" } elseif ($ExeCount -eq 0) { "❌ Keine EXE" } else { "⚠️ Mehrere EXE" }
        Write-Host "   $Status $($App.Name)" -ForegroundColor $(if ($ExeCount -eq 1) { "Green" } elseif ($ExeCount -eq 0) { "Red" } else { "Yellow" })
    }
} else {
    Write-Host "   (Keine Apps gefunden)" -ForegroundColor Gray
    Write-Host "   💡 Tipp: Legen Sie App-Ordner mit EXE-Dateien im 'apps' Verzeichnis an" -ForegroundColor Yellow
}

# Auswahl oder Eingabe eines Unterordners
Write-Host "`n📥 App-Auswahl:" -ForegroundColor Cyan
$InputFolder = Read-Host "Gib den Namen des App-Ordners ein"
$SourceFolder = Join-Path $BaseInputPath $InputFolder
$OutputFolder = Join-Path $BaseOutputPath $InputFolder

# Prüfen, ob der Ordner existiert
if (-not (Test-Path $SourceFolder)) {
    Write-Host "❌ App-Ordner '$InputFolder' nicht gefunden!" -ForegroundColor Red
    Write-Host "📁 Erwarteter Pfad: $SourceFolder" -ForegroundColor Yellow
    exit 1
}

# Prüfen, ob eine .exe vorhanden ist
$ExeFiles = Get-ChildItem -Path $SourceFolder -Filter *.exe
if ($ExeFiles.Count -ne 1) {
    Write-Host "❌ Es muss genau eine .exe im Verzeichnis '$SourceFolder' liegen!" -ForegroundColor Red
    if ($ExeFiles.Count -eq 0) {
        Write-Host "   Keine EXE-Dateien gefunden" -ForegroundColor Yellow
    } else {
        Write-Host "   Gefundene EXE-Dateien:" -ForegroundColor Yellow
        $ExeFiles | ForEach-Object { Write-Host "   - $($_.Name)" -ForegroundColor Yellow }
    }
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
    ScriptVersion = "2.0"
    WorkingDirectory = $ScriptPath
}
$Meta | ConvertTo-Json -Depth 3 | Set-Content -Path "$OutputFolder\metadata.json"

Write-Host "`n📄 Metadaten gespeichert in: .\IntunewinApps\$InputFolder\metadata.json" -ForegroundColor Green
Write-Host "`n🎉 Verpackung abgeschlossen!" -ForegroundColor Green
Write-Host "📁 Ausgabeordner: .\IntunewinApps\$InputFolder" -ForegroundColor Yellow

# Ausgabe der wichtigsten Informationen für Intune
Write-Host "`n📋 Informationen für Microsoft Intune:" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "App-Name: $AppName"
Write-Host "Install-Befehl: install.cmd"
Write-Host "Uninstall-Befehl: uninstall.cmd"
Write-Host "Rückgabecodes: 0 (Erfolg)" + $(if ($ExitCode -eq 3010) { ", 3010 (Neustart erforderlich)" } else { "" })
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

Write-Host "`n💡 Das Skript ist jetzt vollständig portabel und kann überall verwendet werden!" -ForegroundColor Green
