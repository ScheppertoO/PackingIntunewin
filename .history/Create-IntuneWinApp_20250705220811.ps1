# Portable IntuneWin App Packaging Tool
# Arbeitet mit relativen Pfaden - unabhaengig vom Speicherort

# Basis-Pfade relativ zum Skript-Ordner
$ScriptPath = $PSScriptRoot
$BaseInputPath = Join-Path $ScriptPath "apps"
$BaseOutputPath = Join-Path $ScriptPath "IntunewinApps"
$ToolsPath = Join-Path $ScriptPath "IntunewinApps\tools"
$IntuneTool = Join-Path $ToolsPath "IntuneWinAppUtil.exe"
$GitHubRepo = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool"

# Hilfsfunktionen
function Test-IntuneWinAppUtil {
    Write-Host "Pruefe IntuneWinAppUtil.exe..." -ForegroundColor Cyan
    
    # Tools-Ordner erstellen falls nicht vorhanden
    if (-not (Test-Path $ToolsPath)) {
        Write-Host "Erstelle Tools-Ordner: $ToolsPath" -ForegroundColor Yellow
        New-Item -ItemType Directory -Force -Path $ToolsPath | Out-Null
    }
    
    # Pruefen ob IntuneWinAppUtil.exe vorhanden ist
    if (Test-Path $IntuneTool) {
        Write-Host "IntuneWinAppUtil.exe gefunden: $IntuneTool" -ForegroundColor Green
        return $true
    }
    
    Write-Host "IntuneWinAppUtil.exe nicht gefunden, lade von alternativen Quellen herunter..." -ForegroundColor Yellow
    
    try {
        # TLS 1.2 aktivieren (erforderlich fuer moderne Downloads)
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Versuche verschiedene Download-Methoden
        $Downloaded = $false
        
        # Methode 1: Alternative Mirror-Sites und Archive-Quellen
        Write-Host "Versuche alternative Download-Quellen..." -ForegroundColor Yellow
        $AlternativeUrls = @(
            "https://archive.org/download/IntuneWinAppUtil/IntuneWinAppUtil.exe",
            "https://github.com/MSEndpointMgr/IntuneWin32App/raw/master/Tools/IntuneWinAppUtil.exe",
            "https://download.microsoft.com/download/8/b/e/8be61b72-ae5a-4cd9-8b01-6f6c8b8e4f8e/IntuneWinAppUtil.exe",
            "https://aka.ms/intunewinapputildownload"
        )
        
        foreach ($Url in $AlternativeUrls) {
            try {
                Write-Host "  Versuche: $Url" -ForegroundColor Gray
                
                $webClient = New-Object System.Net.WebClient
                $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
                $webClient.Proxy = [System.Net.WebRequest]::DefaultWebProxy
                $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                
                $webClient.DownloadFile($Url, $IntuneTool)
                
                if ((Test-Path $IntuneTool) -and ((Get-Item $IntuneTool).Length -gt 100000)) {
                    Write-Host "Download erfolgreich von: $Url" -ForegroundColor Green
                    $Downloaded = $true
                    break
                } else {
                    if (Test-Path $IntuneTool) { Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue }
                }
                
            } catch {
                Write-Host "URL fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
                if (Test-Path $IntuneTool) { Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue }
            }
        }
        
        # Methode 2: Fallback auf GitHub Source und lokale Kompilierung (falls .NET verfuegbar)
        if (-not $Downloaded) {
            Write-Host "Alle direkten Downloads fehlgeschlagen, versuche Source-Code Download..." -ForegroundColor Yellow
            
            try {
                $SourceUrl = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/archive/refs/tags/v1.8.6.zip"
                $TempZip = Join-Path $env:TEMP "IntuneWinAppUtil_Source_$(Get-Random).zip"
                $TempExtract = Join-Path $env:TEMP "IntuneWinAppUtil_Source_Extract_$(Get-Random)"
                
                $webClient = New-Object System.Net.WebClient
                $webClient.Headers.Add("User-Agent", "PowerShell-IntuneWinAppUtil-Downloader")
                $webClient.Proxy = [System.Net.WebRequest]::DefaultWebProxy
                $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                
                Write-Host "Lade Source-Code herunter..." -ForegroundColor Yellow
                $webClient.DownloadFile($SourceUrl, $TempZip)
                
                if ((Test-Path $TempZip) -and ((Get-Item $TempZip).Length -gt 10000)) {
                    Write-Host "Source-Code erfolgreich heruntergeladen" -ForegroundColor Green
                    
                    # Extrahieren und nach vorkompilierten Binaries suchen
                    Expand-Archive -Path $TempZip -DestinationPath $TempExtract -Force
                    
                    # Suche nach bereits kompilierten EXE-Dateien im Source
                    $ExeFiles = Get-ChildItem -Path $TempExtract -Filter "IntuneWinAppUtil.exe" -Recurse
                    if ($ExeFiles.Count -gt 0) {
                        Copy-Item $ExeFiles[0].FullName $IntuneTool -Force
                        Write-Host "Vorkompilierte EXE aus Source-Code gefunden!" -ForegroundColor Green
                        $Downloaded = $true
                    } else {
                        Write-Host "Keine vorkompilierte EXE im Source-Code gefunden" -ForegroundColor Yellow
                    }
                }
                
                # Aufraeumen
                if (Test-Path $TempZip) { Remove-Item $TempZip -Force -ErrorAction SilentlyContinue }
                if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force -ErrorAction SilentlyContinue }
                
            } catch {
                Write-Host "Source-Code Download fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        # Erfolg pruefen
        if ($Downloaded -and (Test-Path $IntuneTool)) {
            $FileInfo = Get-Item $IntuneTool
            if ($FileInfo.Length -gt 100000) { # Mindestens 100KB
                Write-Host "Download erfolgreich! Dateigroeße: $([math]::Round($FileInfo.Length / 1MB, 2)) MB" -ForegroundColor Green
                
                # Version pruefen falls moeglich
                try {
                    $VersionInfo = & $IntuneTool -v 2>&1
                    if ($VersionInfo -match "(\d+\.\d+\.\d+)") {
                        Write-Host "Tool-Version: $($Matches[1])" -ForegroundColor Green
                    }
                } catch {
                    # Version-Check fehlgeschlagen, aber das ist ok
                }
                
                return $true
            } else {
                Write-Host "Heruntergeladene Datei zu klein (möglicherweise korrupt)" -ForegroundColor Red
                Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Fallback: Detaillierte manuelle Anleitung
        Write-Host "Alle automatischen Download-Methoden fehlgeschlagen!" -ForegroundColor Red
        Write-Host "" 
        Write-Host "=== MANUELLE INSTALLATION ===" -ForegroundColor Yellow
        Write-Host "Das Tool ist leider nicht mehr direkt von GitHub verfuegbar." -ForegroundColor Yellow
        Write-Host "" 
        Write-Host "OPTION 1 - Microsoft Download Center:" -ForegroundColor Cyan
        Write-Host "1. Besuchen Sie: https://aka.ms/win32contentpreptool" -ForegroundColor White
        Write-Host "2. Oder suchen Sie nach 'Microsoft Win32 Content Prep Tool'" -ForegroundColor White
        Write-Host "" 
        Write-Host "OPTION 2 - Alternative Quellen:" -ForegroundColor Cyan
        Write-Host "1. Suchen Sie im Internet nach 'IntuneWinAppUtil.exe download'" -ForegroundColor White
        Write-Host "2. Pruefen Sie PowerShell Gallery oder Chocolatey" -ForegroundColor White
        Write-Host "" 
        Write-Host "OPTION 3 - Aus vorhandenem Intune Admin Center:" -ForegroundColor Cyan
        Write-Host "1. Loggen Sie sich in https://endpoint.microsoft.com ein" -ForegroundColor White
        Write-Host "2. Gehen Sie zu Apps > Windows > Add > Win32 app" -ForegroundColor White
        Write-Host "3. Laden Sie das Tool von dort herunter" -ForegroundColor White
        Write-Host "" 
        Write-Host "Speichern Sie die Datei unter: $ToolsPath" -ForegroundColor White
        Write-Host "===============================" -ForegroundColor Yellow
        return $false
        
    } catch {
        Write-Host "Kritischer Fehler beim Download: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Bitte besuchen Sie manuell: https://aka.ms/win32contentpreptool" -ForegroundColor Yellow
        Write-Host "Laden Sie IntuneWinAppUtil.exe herunter und speichern Sie es unter: $IntuneTool" -ForegroundColor Yellow
        return $false
    }
}

function Get-UninstallInfo {
    param(
        [string]$AppName,
        [string]$ExePath
    )
    
    Write-Host "Suche nach Deinstallationsinformationen fuer '$AppName'..." -ForegroundColor Yellow
    
    # Registry-Pfade fuer installierte Programme
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
                    Write-Host "Gefunden: $($Program.DisplayName)" -ForegroundColor Green
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
    
    Write-Host "Analysiere EXE fuer Deinstallationsparameter..." -ForegroundColor Yellow
    
    # 1. Versuche Help-Output zu analysieren (nur sichere Help-Parameter)
    Write-Host "  Analysiere Help-Output..." -ForegroundColor Gray
    $HelpParams = @("/help", "/?", "-help", "--help", "/h", "-h")
    $HelpOutput = ""
    
    foreach ($HelpParam in $HelpParams) {
        try {
            # Verwende cmd.exe um Output korrekt zu erfassen
            $TempFile = [System.IO.Path]::GetTempFileName()
            $ProcessInfo = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "`"$ExePath`"", $HelpParam, ">", "`"$TempFile`"", "2>&1" -WindowStyle Hidden -Wait -PassThru
            
            if (Test-Path $TempFile) {
                $HelpOutput = Get-Content $TempFile -Raw -ErrorAction SilentlyContinue
                Remove-Item $TempFile -Force -ErrorAction SilentlyContinue
                
                if ($HelpOutput -and $HelpOutput.Trim().Length -gt 10) {
                    Write-Host "  Hilfe-Ausgabe mit $HelpParam erhalten" -ForegroundColor Green
                    break
                }
            }
        }
        catch {
            # Help-Parameter nicht unterstuetzt
        }
    }
    
    # Analysiere Help-Output nach Deinstallationsparametern
    if ($HelpOutput -and $HelpOutput.Length -gt 10) {
        Write-Host "  Suche in Help-Text nach Deinstallationsparametern..." -ForegroundColor Gray
        
        # Erkenne Deinstallations- und Silent-Parameter aus Help
        $UninstallParam = $null
        $SilentParam = $null
        
        # Suche Deinstallationsparameter
        if ($HelpOutput -match "/uninstall\b") { $UninstallParam = "/uninstall" }
        elseif ($HelpOutput -match "/remove\b") { $UninstallParam = "/remove" }
        elseif ($HelpOutput -match "/u\b") { $UninstallParam = "/u" }
        elseif ($HelpOutput -match "/x\b") { $UninstallParam = "/x" }
        elseif ($HelpOutput -match "-uninstall\b") { $UninstallParam = "-uninstall" }
        elseif ($HelpOutput -match "-remove\b") { $UninstallParam = "-remove" }
        elseif ($HelpOutput -match "-u\b") { $UninstallParam = "-u" }
        
        # Suche Silent-Parameter
        if ($HelpOutput -match "/silent\b") { $SilentParam = "/silent" }
        elseif ($HelpOutput -match "/quiet\b") { $SilentParam = "/quiet" }
        elseif ($HelpOutput -match "/s\b") { $SilentParam = "/s" }
        elseif ($HelpOutput -match "/q\b") { $SilentParam = "/q" }
        elseif ($HelpOutput -match "-silent\b") { $SilentParam = "-silent" }
        elseif ($HelpOutput -match "-quiet\b") { $SilentParam = "-quiet" }
        elseif ($HelpOutput -match "-s\b") { $SilentParam = "-s" }
        elseif ($HelpOutput -match "-q\b") { $SilentParam = "-q" }
        
        if ($UninstallParam) {
            $SilentParam = if ($SilentParam) { $SilentParam } else { "/silent" }
            Write-Host "  Parameter aus Help erkannt: $UninstallParam $SilentParam" -ForegroundColor Green
            return "$UninstallParam $SilentParam"
        }
    }
    
    # 2. EXE-Metadaten pruefen (ohne Ausfuehrung)
    Write-Host "  Pruefe EXE-Metadaten..." -ForegroundColor Gray
    try {
        $FileInfo = Get-Item $ExePath
        $VersionInfo = $FileInfo.VersionInfo
        
        $CompanyName = if ($VersionInfo.CompanyName) { $VersionInfo.CompanyName.ToLower() } else { "" }
        $ProductName = if ($VersionInfo.ProductName) { $VersionInfo.ProductName.ToLower() } else { "" }
        $Description = if ($VersionInfo.FileDescription) { $VersionInfo.FileDescription.ToLower() } else { "" }
        
        # Bekannte Installer-Typen
        if ($Description -like "*nsis*" -or $ProductName -like "*nsis*") {
            Write-Host "  NSIS Installer erkannt" -ForegroundColor Green
            return "/S"
        }
        elseif ($Description -like "*inno setup*" -or $ProductName -like "*inno setup*") {
            Write-Host "  Inno Setup Installer erkannt" -ForegroundColor Green
            return "/SILENT"
        }
        elseif ($Description -like "*installshield*" -or $ProductName -like "*installshield*") {
            Write-Host "  InstallShield Installer erkannt" -ForegroundColor Green
            return "/s /uninst"
        }
        elseif ($Description -like "*windows installer*" -or $ProductName -like "*msi*") {
            Write-Host "  MSI-basierter Installer erkannt" -ForegroundColor Green
            return "/uninstall /quiet"
        }
        elseif ($CompanyName -like "*microsoft*" -and $ProductName -like "*visual*") {
            return "/uninstall /quiet"
        }
    }
    catch {
        Write-Host "  Metadaten-Analyse nicht moeglich" -ForegroundColor Gray
    }
    
    # 3. Dateiname-basierte Heuristik
    Write-Host "  Analysiere Dateiname..." -ForegroundColor Gray
    $FileName = [System.IO.Path]::GetFileNameWithoutExtension($ExePath).ToLower()
    
    # Installer-Typ aus Dateiname ableiten
    if ($FileName -like "*setup*" -or $FileName -like "*install*") {
        Write-Host "  Setup/Installer erkannt aus Dateiname" -ForegroundColor Green
        
        if ($FileName -like "*nsis*") {
            return "/S"
        } elseif ($FileName -like "*inno*") {
            return "/SILENT"
        } else {
            return "/uninstall /silent"
        }
    } elseif ($FileName -like "*msi*") {
        Write-Host "  MSI-bezogen erkannt aus Dateiname" -ForegroundColor Green
        return "/x /quiet"
    }
    
    # 4. Sichere Fallback-Heuristik
    Write-Host "  Keine spezifischen Parameter erkannt, verwende Standard-Heuristik" -ForegroundColor Yellow
    
    # Waehle haeufigsten Standard basierend auf Dateiname
    if ($FileName -like "*setup*") {
        $SelectedParams = "/uninstall /silent"
    }
    elseif ($FileName -like "*install*") {
        $SelectedParams = "/remove /quiet"
    }
    else {
        $SelectedParams = "/uninstall /silent"  # Haeufigster Standard
    }
    
    Write-Host "  Empfohlene Parameter: $SelectedParams" -ForegroundColor Yellow
    Write-Host "  Tipp: Manuelle Ueberpruefung der Deinstallation nach Bereitstellung" -ForegroundColor Gray
    
    return $SelectedParams
}

function Initialize-Folders {
    Write-Host "Initialisiere Ordnerstruktur..." -ForegroundColor Cyan
    
    # Benoetigte Ordner erstellen
    $RequiredFolders = @($BaseInputPath, $BaseOutputPath, $ToolsPath)
    
    foreach ($Folder in $RequiredFolders) {
        if (-not (Test-Path $Folder)) {
            Write-Host "   Erstelle: $($Folder -replace [regex]::Escape($ScriptPath), '.')" -ForegroundColor Yellow
            New-Item -ItemType Directory -Force -Path $Folder | Out-Null
        }
    }
    
    Write-Host "Ordnerstruktur bereit" -ForegroundColor Green
    Write-Host "   Apps: $(Split-Path $BaseInputPath -Leaf)" -ForegroundColor Gray
    Write-Host "   Output: $(Split-Path $BaseOutputPath -Leaf)" -ForegroundColor Gray
    Write-Host "   Tools: $(Split-Path $ToolsPath -Leaf)" -ForegroundColor Gray
}

# Tool-Verfuegbarkeit pruefen
Write-Host "Starte Portable IntuneWin App Packaging Tool" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Arbeitsverzeichnis: $ScriptPath" -ForegroundColor Gray

# Ordnerstruktur initialisieren
Initialize-Folders

if (-not (Test-IntuneWinAppUtil)) {
    Write-Host "IntuneWinAppUtil.exe konnte nicht bereitgestellt werden!" -ForegroundColor Red
    Write-Host "Moegliche Loesungen:" -ForegroundColor Yellow
    Write-Host "   1. Internetverbindung pruefen" -ForegroundColor Yellow
    Write-Host "   2. Manuell von $GitHubRepo herunterladen" -ForegroundColor Yellow
    Write-Host "   3. Tool unter $(Split-Path $IntuneTool -Leaf) speichern" -ForegroundColor Yellow
    exit 1
}

# Verfuegbare Apps anzeigen
Write-Host "`nVerfuegbare Apps im 'apps' Ordner:" -ForegroundColor Cyan
$AvailableApps = Get-ChildItem -Path $BaseInputPath -Directory -ErrorAction SilentlyContinue | Sort-Object Name
if ($AvailableApps.Count -gt 0) {
    foreach ($App in $AvailableApps) {
        $ExeCount = (Get-ChildItem -Path $App.FullName -Filter "*.exe" -ErrorAction SilentlyContinue).Count
        $Status = if ($ExeCount -eq 1) { "OK" } elseif ($ExeCount -eq 0) { "Keine EXE" } else { "Mehrere EXE" }
        Write-Host "   $Status $($App.Name)" -ForegroundColor $(if ($ExeCount -eq 1) { "Green" } elseif ($ExeCount -eq 0) { "Red" } else { "Yellow" })
    }
} else {
    Write-Host "   (Keine Apps gefunden)" -ForegroundColor Gray
    Write-Host "   Tipp: Legen Sie App-Ordner mit EXE-Dateien im 'apps' Verzeichnis an" -ForegroundColor Yellow
}

# Auswahl oder Eingabe eines Unterordners
Write-Host "`nApp-Auswahl:" -ForegroundColor Cyan
$InputFolder = Read-Host "Gib den Namen des App-Ordners ein"
$SourceFolder = Join-Path $BaseInputPath $InputFolder
$OutputFolder = Join-Path $BaseOutputPath $InputFolder

# Pruefen, ob der Ordner existiert
if (-not (Test-Path $SourceFolder)) {
    Write-Host "App-Ordner '$InputFolder' nicht gefunden!" -ForegroundColor Red
    Write-Host "Erwarteter Pfad: $SourceFolder" -ForegroundColor Yellow
    exit 1
}

# Pruefen, ob eine .exe vorhanden ist
$ExeFiles = Get-ChildItem -Path $SourceFolder -Filter *.exe
if ($ExeFiles.Count -ne 1) {
    Write-Host "Es muss genau eine .exe im Verzeichnis '$SourceFolder' liegen!" -ForegroundColor Red
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

# Rueckfrage, ob ein Neustart nach der Installation erforderlich ist
$RebootRequired = Read-Host "Erfordert die Installation einen Neustart? (j/n)"
if ($RebootRequired -eq 'j') {
    $ExitCode = 3010  # Soft reboot required
} else {
    $ExitCode = 0     # Normaler Erfolg
}

# Deinstallationsinformationen ermitteln
Write-Host "`nErmittle Deinstallationsinformationen..." -ForegroundColor Cyan

# Erst Registry durchsuchen
$UninstallInfo = Get-UninstallInfo -AppName $AppName -ExePath $ExePath

$UninstallCommand = ""
if ($UninstallInfo.Found) {
    Write-Host "Registry-Eintrag gefunden!" -ForegroundColor Green
    
    if ($UninstallInfo.QuietUninstallString) {
        $UninstallCommand = $UninstallInfo.QuietUninstallString
        Write-Host "Verwende QuietUninstallString: $UninstallCommand" -ForegroundColor Green
    } else {
        # Versuche, /quiet oder /silent zur UninstallString hinzuzufuegen
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
        Write-Host "Verwende modifizierte UninstallString: $UninstallCommand" -ForegroundColor Yellow
    }
} else {
    Write-Host "Kein Registry-Eintrag gefunden, teste EXE-Parameter..." -ForegroundColor Yellow
    $UninstallParams = Test-ExeUninstallParameters -ExePath $ExePath
    $UninstallCommand = "$ExeName $UninstallParams"
    Write-Host "Verwende EXE mit Parametern: $UninstallCommand" -ForegroundColor Yellow
}

# Ausgabe
Write-Host "`nZusammenfassung:" -ForegroundColor Cyan
Write-Host "Gefundene EXE: $ExeName"
Write-Host "App-Name wird gesetzt auf: $AppName"
Write-Host "Exit-Code wird auf $ExitCode gesetzt"
Write-Host "Deinstallation: $UninstallCommand"

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

Write-Host "`nErstelle Batch-Dateien..." -ForegroundColor Cyan
Write-Host "install.cmd erstellt"
Write-Host "uninstall.cmd erstellt"

# .intunewin erstellen
Write-Host "`nErstelle .intunewin Paket..." -ForegroundColor Cyan
& $IntuneTool -c $SourceFolder -s "install.cmd" -o $OutputFolder

# Pruefen ob .intunewin erfolgreich erstellt wurde
$IntunewinFile = Get-ChildItem -Path $OutputFolder -Filter "*.intunewin" | Select-Object -First 1
if ($IntunewinFile) {
    Write-Host ".intunewin Paket erfolgreich erstellt: $($IntunewinFile.Name)" -ForegroundColor Green
} else {
    Write-Host "Fehler beim Erstellen des .intunewin Pakets!" -ForegroundColor Red
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

Write-Host "`nMetadaten gespeichert in: .\IntunewinApps\$InputFolder\metadata.json" -ForegroundColor Green
Write-Host "`nVerpackung abgeschlossen!" -ForegroundColor Green
Write-Host "Ausgabeordner: .\IntunewinApps\$InputFolder" -ForegroundColor Yellow

# Ausgabe der wichtigsten Informationen fuer Intune
Write-Host "`nInformationen fuer Microsoft Intune:" -ForegroundColor Cyan
Write-Host "====================================="
Write-Host "App-Name: $AppName"
Write-Host "Install-Befehl: install.cmd"
Write-Host "Uninstall-Befehl: uninstall.cmd"
Write-Host "Rueckgabecodes: 0 (Erfolg)" + $(if ($ExitCode -eq 3010) { ", 3010 (Neustart erforderlich)" } else { "" })
Write-Host "====================================="

Write-Host "`nDas Skript ist jetzt vollstaendig portabel und kann ueberall verwendet werden!" -ForegroundColor Green
