# Interaktive Abfrage des Input-Pfades
$BaseInputPath = "C:\Packaging\Input"
$BaseOutputPath = "C:\Packaging\Output"
$IntuneTool = "C:\Tools\IntuneWinAppUtil.exe"

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
$AppName = [System.IO.Path]::GetFileNameWithoutExtension($ExeName)

# Ausgabe
Write-Host "✅ Gefundene EXE: $ExeName"
Write-Host "📦 App-Name wird gesetzt auf: $AppName"

# Ausgabeordner vorbereiten
New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null

# install.cmd dynamisch erstellen
$InstallCmd = @"
@echo off
$ExeName /silent
exit /b 0
"@
Set-Content -Path "$SourceFolder\install.cmd" -Value $InstallCmd -Encoding ASCII

# .intunewin erstellen
& $IntuneTool -c $SourceFolder -s "install.cmd" -o $OutputFolder

# Metadaten schreiben
$Meta = @{
    AppName = $AppName
    Installer = $ExeName
    InstallCommand = "install.cmd"
    DetectionType = "Registry (manuell konfigurieren)"
    CreatedOn = (Get-Date).ToString("yyyy-MM-dd HH:mm")
}
$Meta | ConvertTo-Json -Depth 3 | Set-Content -Path "$OutputFolder\metadata.json"
