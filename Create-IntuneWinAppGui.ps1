# IntuneWin App Packaging Tool - WPF GUI
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Basis-Pfade relativ zum Skript-Ordner
$ScriptPath = $PSScriptRoot
$BaseInputPath = Join-Path $ScriptPath "apps"
$BaseOutputPath = Join-Path $ScriptPath "IntunewinApps"
$ToolsPath = Join-Path $ScriptPath "IntunewinApps\tools"
$IntuneTool = Join-Path $ToolsPath "IntuneWinAppUtil.exe"
$GitHubRepo = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool"

# XAML-Definition fuer die GUI
[xml]$xaml = @"
<Window 
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="IntuneWin App Packaging Tool" Height="650" Width="800" WindowStartupLocation="CenterScreen">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Margin" Value="5"/>
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="MinWidth" Value="100"/>
        </Style>
        <Style TargetType="TextBlock">
            <Setter Property="Margin" Value="0,5,0,2"/>
        </Style>
        <Style TargetType="ComboBox">
            <Setter Property="Margin" Value="0,0,0,10"/>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Margin" Value="0,5,0,5"/>
        </Style>
    </Window.Resources>
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Header -->
        <StackPanel Grid.Row="0">
            <TextBlock FontSize="20" FontWeight="Bold">IntuneWin App Packaging Tool</TextBlock>
            <TextBlock x:Name="lblWorkingDir" Margin="0,0,0,10" Foreground="Gray"></TextBlock>
            <Separator/>
        </StackPanel>
        
        <!-- App Selection -->
        <GroupBox Grid.Row="1" Header="App-Auswahl" Margin="0,10,0,10" Padding="10">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                
                <ComboBox Grid.Row="0" Grid.Column="0" x:Name="cboAppFolder" Margin="0,0,5,0"/>
                <Button Grid.Row="0" Grid.Column="1" x:Name="btnRefreshApps">Aktualisieren</Button>
                
                <Button Grid.Row="1" Grid.Column="0" Grid.ColumnSpan="2" x:Name="btnOpenAppFolder" 
                        Margin="0,10,0,0" HorizontalAlignment="Left">Apps-Ordner oeffnen</Button>
            </Grid>
        </GroupBox>
        
        <!-- Configuration -->
        <GroupBox Grid.Row="2" Header="Konfiguration" Margin="0,0,0,10" Padding="10">
            <StackPanel>
                <CheckBox x:Name="chkRebootRequired">Neustart nach Installation erforderlich</CheckBox>
            </StackPanel>
        </GroupBox>
        
        <!-- Actions -->
        <GroupBox Grid.Row="3" Header="Aktionen" Margin="0,0,0,10" Padding="10">
            <StackPanel Orientation="Horizontal">
                <Button x:Name="btnInitialize" ToolTip="Ordnerstruktur initialisieren">Initialisieren</Button>
                <Button x:Name="btnCheckTool" ToolTip="IntuneWinAppUtil.exe ueberpruefen/herunterladen">Tool pruefen</Button>
                <Button x:Name="btnCreatePackage" IsEnabled="False" Background="LightGreen">Paket erstellen</Button>
                <Button x:Name="btnOpenOutputFolder" IsEnabled="False">Output-Ordner oeffnen</Button>
            </StackPanel>
        </GroupBox>
        
        <!-- Status -->
        <GroupBox Grid.Row="4" Header="Status" Margin="0,0,0,10" Padding="10">
            <StackPanel>
                <TextBlock x:Name="lblStatus" Text="Bereit. Bitte waehle eine App aus." TextWrapping="Wrap"/>
                <ProgressBar x:Name="progressBar" Height="15" Margin="0,5,0,0" Visibility="Collapsed"/>
            </StackPanel>
        </GroupBox>
        
        <!-- Log Output -->
        <GroupBox Grid.Row="5" Header="Log" Margin="0,0,0,10" Padding="10">
            <TextBox x:Name="txtLog" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" 
                     Background="#F0F0F0" FontFamily="Consolas"/>
        </GroupBox>
        
        <!-- Footer -->
        <StackPanel Grid.Row="6" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="btnExit" Width="100">Beenden</Button>
        </StackPanel>
    </Grid>
</Window>
"@

# XAML laden und in WPF-Objekt umwandeln
$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Elemente der GUI abrufen
$elements = @{}
$xaml.SelectNodes("//*[@*[contains(translate(name(.),'x:',''),'Name')]]") | ForEach-Object {
    $name = $_.Name
    $elements[$name] = $window.FindName($name)
}

# Hilfsfunktionen fuer die GUI
function Write-Log {
    param([string]$Message, [string]$Color = "Black")
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    
    $elements.txtLog.Dispatcher.Invoke(
        [action]{
            $elements.txtLog.AppendText("$logEntry`r`n")
            $elements.txtLog.ScrollToEnd()
        }
    )
    
    # Status-Label aktualisieren
    $elements.lblStatus.Dispatcher.Invoke(
        [action]{
            $elements.lblStatus.Text = $Message
            $elements.lblStatus.Foreground = $Color
        }
    )
}

function Initialize-GUI {
    # Arbeitsverzeichnis anzeigen
    $elements.lblWorkingDir.Text = "Arbeitsverzeichnis: $ScriptPath"
    
    # Event-Handler fuer Buttons
    $elements.btnInitialize.Add_Click({ Initialize-FoldersGUI })
    $elements.btnCheckTool.Add_Click({ Test-IntuneWinAppUtilGUI })
    $elements.btnCreatePackage.Add_Click({ Create-IntuneWinAppPackage })
    $elements.btnExit.Add_Click({ $window.Close() })
    $elements.btnRefreshApps.Add_Click({ Refresh-AppList })
    $elements.btnOpenAppFolder.Add_Click({ Start-Process -FilePath "explorer.exe" -ArgumentList $BaseInputPath })
    $elements.btnOpenOutputFolder.Add_Click({
        $selectedApp = $elements.cboAppFolder.SelectedItem
        if ($selectedApp) {
            $outputFolder = Join-Path $BaseOutputPath $selectedApp
            if (Test-Path $outputFolder) {
                Start-Process -FilePath "explorer.exe" -ArgumentList $outputFolder
            }
            else {
                Write-Log "Output-Ordner existiert noch nicht: $outputFolder" "Red"
            }
        }
    })
    
    # ComboBox aenderung ueberwachen
    $elements.cboAppFolder.Add_SelectionChanged({
        $selectedApp = $elements.cboAppFolder.SelectedItem
        if ($selectedApp) {
            $elements.btnCreatePackage.IsEnabled = $true
            $elements.btnOpenOutputFolder.IsEnabled = $true
            $sourceFolder = Join-Path $BaseInputPath $selectedApp
            
            # Pruefe auf EXE-Dateien
            $exeFiles = Get-ChildItem -Path $sourceFolder -Filter *.exe -ErrorAction SilentlyContinue
            if ($exeFiles.Count -eq 1) {
                Write-Log "App ausgewaehlt: $selectedApp (mit $($exeFiles[0].Name))" "Blue"
            } 
            elseif ($exeFiles.Count -eq 0) {
                Write-Log "WARNUNG: Keine EXE-Dateien in $selectedApp gefunden!" "Red"
                $elements.btnCreatePackage.IsEnabled = $false
            }
            else {
                Write-Log "WARNUNG: Mehrere EXE-Dateien in $selectedApp gefunden. Erste wird verwendet: $($exeFiles[0].Name)" "Orange"
            }
        }
        else {
            $elements.btnCreatePackage.IsEnabled = $false
            $elements.btnOpenOutputFolder.IsEnabled = $false
        }
    })
    
    # App-Liste initial laden
    Refresh-AppList
    
    Write-Log "IntuneWin App Packaging Tool gestartet" "Blue"
}

function Refresh-AppList {
    $elements.cboAppFolder.Items.Clear()
    
    # Pruefe, ob der Basis-Input-Pfad existiert
    if (-not (Test-Path $BaseInputPath)) {
        Write-Log "Apps-Ordner nicht gefunden. Bitte initialisiere die Ordnerstruktur." "Red"
        return
    }
    
    # Verfuegbare App-Ordner auflisten
    $appFolders = Get-ChildItem -Path $BaseInputPath -Directory | Sort-Object Name
    
    if ($appFolders.Count -gt 0) {
        foreach ($folder in $appFolders) {
            $elements.cboAppFolder.Items.Add($folder.Name)
        }
        Write-Log "$($appFolders.Count) App-Ordner gefunden" "Green"
    }
    else {
        Write-Log "Keine App-Ordner gefunden. Bitte lege Ordner mit EXE-Dateien im 'apps' Verzeichnis an." "Orange"
    }
}

function Initialize-FoldersGUI {
    Write-Log "Initialisiere Ordnerstruktur..." "Blue"
    
    # Benoetigte Ordner erstellen
    $RequiredFolders = @($BaseInputPath, $BaseOutputPath, $ToolsPath)
    
    foreach ($Folder in $RequiredFolders) {
        if (-not (Test-Path $Folder)) {
            Write-Log "   Erstelle: $($Folder -replace [regex]::Escape($ScriptPath), '.')" 
            New-Item -ItemType Directory -Force -Path $Folder | Out-Null
        }
    }
    
    Write-Log "Ordnerstruktur erfolgreich initialisiert" "Green"
    Write-Log "   Apps: $(Split-Path $BaseInputPath -Leaf)"
    Write-Log "   Output: $(Split-Path $BaseOutputPath -Leaf)"
    Write-Log "   Tools: $(Split-Path $ToolsPath -Leaf)"
    
    # App-Liste aktualisieren
    Refresh-AppList
}

function Test-IntuneWinAppUtilGUI {
    Write-Log "Pruefe IntuneWinAppUtil.exe..." "Blue"
    
    # Tools-Ordner erstellen falls nicht vorhanden
    if (-not (Test-Path $ToolsPath)) {
        Write-Log "Erstelle Tools-Ordner: $ToolsPath"
        New-Item -ItemType Directory -Force -Path $ToolsPath | Out-Null
    }
    
    # Pruefen ob IntuneWinAppUtil.exe vorhanden ist
    if (Test-Path $IntuneTool) {
        Write-Log "IntuneWinAppUtil.exe gefunden: $IntuneTool" "Green"
        return $true
    }
    
    Write-Log "IntuneWinAppUtil.exe nicht gefunden, lade von GitHub herunter..." "Orange"
    
    try {
        # Progress Bar anzeigen
        $elements.progressBar.Visibility = "Visible"
        $elements.progressBar.IsIndeterminate = $true
        
        # Versuche verschiedene Download-Methoden
        $Downloaded = $false
        
        # Methode 1: GitHub Releases API (fuer ZIP-Dateien)
        Write-Log "Suche nach der neuesten Version..."
        $ApiUrl = "https://api.github.com/repos/microsoft/Microsoft-Win32-Content-Prep-Tool/releases/latest"
        $Release = Invoke-RestMethod -Uri $ApiUrl -ErrorAction Stop
        
        # Suche nach ZIP-Dateien in den Assets
        $ZipAsset = $Release.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
        
        if ($ZipAsset) {
            Write-Log "Gefunden: $($ZipAsset.name) (Version: $($Release.tag_name))" "Green"
            Write-Log "Download-URL: $($ZipAsset.browser_download_url)" 
            
            # Temporaeres Verzeichnis fuer Download
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
                Write-Log "IntuneWinAppUtil.exe erfolgreich extrahiert!" "Green"
                $Downloaded = $true
            }
            
            # Aufraeumen
            if (Test-Path $TempZip) { Remove-Item $TempZip -Force }
            if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force }
        }
        
        # Methode 2: Direkte URLs (Fallback)
        if (-not $Downloaded) {
            Write-Log "Kein ZIP in Release gefunden, versuche direkte Download-URLs..." "Orange"
            
            # Bekannte direkte URLs
            $DirectUrls = @(
                "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/releases/download/v1.8.6/IntuneWinAppUtil.exe",
                "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/releases/latest/download/IntuneWinAppUtil.exe"
            )
            
            foreach ($Url in $DirectUrls) {
                try {
                    Write-Log "  Versuche: $Url" 
                    $WebClient = New-Object System.Net.WebClient
                    $WebClient.DownloadFile($Url, $IntuneTool)
                    
                    if (Test-Path $IntuneTool) {
                        Write-Log "Download erfolgreich!" "Green"
                        $Downloaded = $true
                        break
                    }
                } catch {
                    Write-Log "URL fehlgeschlagen: $($_.Exception.Message)" "Red"
                }
            }
        }
        
        # Erfolg pruefen
        if ($Downloaded -and (Test-Path $IntuneTool)) {
            $FileInfo = Get-Item $IntuneTool
            Write-Log "Download erfolgreich! Dateigroeße: $([math]::Round($FileInfo.Length / 1MB, 2)) MB" "Green"
            return $true
        } else {
            Write-Log "Alle Download-Methoden fehlgeschlagen!" "Red"
            [System.Windows.Forms.MessageBox]::Show(
                "Download fehlgeschlagen! Bitte IntuneWinAppUtil.exe manuell herunterladen und im Tools-Ordner ablegen.",
                "Download-Fehler",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            return $false
        }
        
    } catch {
        Write-Log "Fehler beim Download: $($_.Exception.Message)" "Red"
        [System.Windows.Forms.MessageBox]::Show(
            "Fehler beim Download! Bitte IntuneWinAppUtil.exe manuell herunterladen und im Tools-Ordner ablegen.",
            "Download-Fehler",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return $false
    } finally {
        # Progress Bar ausblenden
        $elements.progressBar.Visibility = "Collapsed"
        $elements.progressBar.IsIndeterminate = $false
    }
}

function Get-UninstallInfoGUI {
    param(
        [string]$AppName,
        [string]$ExePath
    )
    
    Write-Log "Suche nach Deinstallationsinformationen fuer '$AppName'..." "Blue"
    
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
                    Write-Log "Gefunden: $($Program.DisplayName)" "Green"
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

function Test-ExeUninstallParametersGUI {
    param([string]$ExePath)
    
    Write-Log "Analysiere EXE fuer Deinstallationsparameter..." "Blue"
    
    # Dateiname-basierte Heuristik
    Write-Log "Analysiere Dateiname..."
    $FileName = [System.IO.Path]::GetFileNameWithoutExtension($ExePath).ToLower()
    
    # Installer-Typ aus Dateiname ableiten
    if ($FileName -like "*setup*" -or $FileName -like "*install*") {
        Write-Log "Setup/Installer erkannt aus Dateiname" "Green"
        
        if ($FileName -like "*nsis*") {
            return "/S"
        } elseif ($FileName -like "*inno*") {
            return "/SILENT"
        } else {
            return "/uninstall /silent"
        }
    } elseif ($FileName -like "*msi*") {
        Write-Log "MSI-bezogen erkannt aus Dateiname" "Green"
        return "/x /quiet"
    }
    
    # Sichere Fallback-Heuristik
    Write-Log "Keine spezifischen Parameter erkannt, verwende Standard-Heuristik" "Orange"
    
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
    
    Write-Log "Empfohlene Parameter: $SelectedParams" "Orange"
    return $SelectedParams
}

function Create-IntuneWinAppPackage {
    # Ausgewaehlte App holen
    $InputFolder = $elements.cboAppFolder.SelectedItem
    
    if (-not $InputFolder) {
        Write-Log "Bitte waehle eine App aus!" "Red"
        return
    }
    
    # Pfade definieren
    $SourceFolder = Join-Path $BaseInputPath $InputFolder
    $OutputFolder = Join-Path $BaseOutputPath $InputFolder
    
    # Pruefen, ob der Ordner existiert
    if (-not (Test-Path $SourceFolder)) {
        Write-Log "App-Ordner '$InputFolder' nicht gefunden!" "Red"
        return
    }
    
    # Pruefe Tool-Verfuegbarkeit
    if (-not (Test-Path $IntuneTool)) {
        $toolResult = Test-IntuneWinAppUtilGUI
        if (-not $toolResult) {
            Write-Log "Erforderliches Tool fehlt: IntuneWinAppUtil.exe" "Red"
            return
        }
    }
    
    # Pruefen, ob eine .exe vorhanden ist
    $ExeFiles = Get-ChildItem -Path $SourceFolder -Filter *.exe
    if ($ExeFiles.Count -eq 0) {
        Write-Log "Keine .exe im Verzeichnis '$SourceFolder' gefunden!" "Red"
        return
    }
    
    $ExeName = $ExeFiles[0].Name
    $ExePath = $ExeFiles[0].FullName
    $AppName = [System.IO.Path]::GetFileNameWithoutExtension($ExeName)
    
    Write-Log "Starte Paketierung fuer $AppName..." "Blue"
    
    # Reboot-Einstellung pruefen
    $RebootRequired = $elements.chkRebootRequired.IsChecked
    if ($RebootRequired) {
        $ExitCode = 3010  # Soft reboot required
        Write-Log "Neustart nach Installation wird erforderlich sein (Exit-Code: 3010)" "Orange"
    } else {
        $ExitCode = 0     # Normaler Erfolg
        Write-Log "Kein Neustart erforderlich (Exit-Code: 0)" "Green"
    }
    
    # Deinstallationsinformationen ermitteln
    $UninstallInfo = Get-UninstallInfoGUI -AppName $AppName -ExePath $ExePath
    
    $UninstallCommand = ""
    if ($UninstallInfo.Found) {
        Write-Log "Registry-Eintrag gefunden!" "Green"
        
        if ($UninstallInfo.QuietUninstallString) {
            $UninstallCommand = $UninstallInfo.QuietUninstallString
            Write-Log "Verwende QuietUninstallString: $UninstallCommand" "Green"
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
            Write-Log "Verwende modifizierte UninstallString: $UninstallCommand" "Orange"
        }
    } else {
        Write-Log "Kein Registry-Eintrag gefunden, teste EXE-Parameter..." "Orange"
        $UninstallParams = Test-ExeUninstallParametersGUI -ExePath $ExePath
        $UninstallCommand = "$ExeName $UninstallParams"
        Write-Log "Verwende EXE mit Parametern: $UninstallCommand" "Orange"
    }
    
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
    Write-Log "install.cmd erstellt" "Green"
    
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
    Write-Log "uninstall.cmd erstellt" "Green"
    
    # Progress Bar anzeigen
    $elements.progressBar.Visibility = "Visible"
    $elements.progressBar.IsIndeterminate = $true
    
    # .intunewin erstellen (im Hintergrund)
    Write-Log "Erstelle .intunewin Paket (dies kann einen Moment dauern)..." "Blue"
    
    $job = Start-Job -ScriptBlock {
        param ($IntuneTool, $SourceFolder, $OutputFolder)
        & $IntuneTool -c $SourceFolder -s "install.cmd" -o $OutputFolder
    } -ArgumentList $IntuneTool, $SourceFolder, $OutputFolder
    
    # Warten bis Job beendet
    while ($job.State -eq "Running") {
        Start-Sleep -Milliseconds 500
    }
    
    # Job-Ergebnis pruefen
    $jobOutput = Receive-Job -Job $job
    Remove-Job -Job $job
    
    # Progress Bar ausblenden
    $elements.progressBar.Visibility = "Collapsed"
    $elements.progressBar.IsIndeterminate = $false
    
    # Pruefen ob .intunewin erfolgreich erstellt wurde
    $IntunewinFile = Get-ChildItem -Path $OutputFolder -Filter "*.intunewin" | Select-Object -First 1
    if ($IntunewinFile) {
        Write-Log ".intunewin Paket erfolgreich erstellt: $($IntunewinFile.Name)" "Green"
    } else {
        Write-Log "Fehler beim Erstellen des .intunewin Pakets!" "Red"
        Write-Log "Tool-Ausgabe: $jobOutput" "Red"
        return
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
        ScriptVersion = "2.0 GUI"
        WorkingDirectory = $ScriptPath
    }
    $Meta | ConvertTo-Json -Depth 3 | Set-Content -Path "$OutputFolder\metadata.json"
    
    Write-Log "Metadaten gespeichert in: metadata.json" "Green"
    Write-Log "Verpackung abgeschlossen!" "Green"
    
    # Zusammenfassung
    Write-Log "`nZusammenfassung fuer Intune:" "Blue"
    Write-Log "====================================="
    Write-Log "App-Name: $AppName"
    Write-Log "Install-Befehl: install.cmd"
    Write-Log "Uninstall-Befehl: uninstall.cmd"
    Write-Log "Rueckgabecodes: 0 (Erfolg)" + $(if ($ExitCode -eq 3010) { ", 3010 (Neustart erforderlich)" } else { "" })
    Write-Log "====================================="
    
    # Frage, ob der Ausgabeordner geoeffnet werden soll
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Paket erfolgreich erstellt. Moechten Sie den Ausgabeordner oeffnen?",
        "Paket erstellt",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
    
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        Start-Process -FilePath "explorer.exe" -ArgumentList $OutputFolder
    }
}

# GUI initialisieren und anzeigen
Initialize-GUI
$window.ShowDialog() | Out-Null