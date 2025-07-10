# IntuneWin App Packaging Tool - WPF GUI
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Base paths relative to main directory (one level up from scripts folder)
$ScriptPath = Split-Path $PSScriptRoot -Parent
$BaseInputPath = Join-Path $ScriptPath "apps"
$BaseOutputPath = Join-Path $ScriptPath "IntunewinApps"
$ToolsPath = Join-Path $ScriptPath "tools"
$IntuneTool = Join-Path $ToolsPath "IntuneWinAppUtil.exe"

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
    $elements.btnCreatePackage.Add_Click({ New-IntuneWinAppPackage })
    $elements.btnExit.Add_Click({ $window.Close() })
    $elements.btnRefreshApps.Add_Click({ Update-AppList })
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
    Update-AppList
    
    Write-Log "IntuneWin App Packaging Tool gestartet" "Blue"
}

function Update-AppList {
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
    Update-AppList
}

function Test-IntuneWinAppUtilGUI {
    Write-Log "Pruefe IntuneWinAppUtil.exe..." "Blue"
    
    # Tools-Ordner erstellen falls nicht vorhanden
    if (-not (Test-Path $ToolsPath)) {
        Write-Log "Erstelle Tools-Ordner: $ToolsPath"
        New-Item -ItemType Directory -Force -Path $ToolsPath | Out-Null
    }
    
    # Pruefen ob IntuneWinAppUtil.exe vorhanden ist und funktioniert
    if (Test-Path $IntuneTool) {
        Write-Log "IntuneWinAppUtil.exe gefunden: $IntuneTool" "Green"
        
        # Datei-Integritaet pruefen
        try {
            $FileInfo = Get-Item $IntuneTool
            if ($FileInfo.Length -lt 100000) {
                Write-Log "WARNUNG: Datei zu klein ($([math]::Round($FileInfo.Length / 1KB, 2)) KB), moeglicherweise beschaedigt" "Orange"
                Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
            } else {
                # Funktionstest durchfuehren
                try {
                    $testResult = & $IntuneTool /? 2>&1
                    if ($LASTEXITCODE -eq 0 -or $testResult -match "IntuneWinAppUtil|Microsoft") {
                        Write-Log "Tool-Funktionstest erfolgreich" "Green"
                        return $true
                    } else {
                        Write-Log "WARNUNG: Tool-Funktionstest fehlgeschlagen, lade neu herunter" "Orange"
                        Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
                    }
                } catch {
                    Write-Log "WARNUNG: Tool beschaedigt ($($_.Exception.Message)), lade neu herunter" "Orange"
                    Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
                }
            }
        } catch {
            Write-Log "WARNUNG: Kann Datei nicht lesen ($($_.Exception.Message)), lade neu herunter" "Orange"
            Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
        }
    }
    
    Write-Log "Lade IntuneWinAppUtil.exe herunter..." "Orange"
    
    try {
        # Progress Bar anzeigen
        $elements.progressBar.Visibility = "Visible"
        $elements.progressBar.IsIndeterminate = $true
        
        # TLS 1.2 aktivieren (erforderlich fuer moderne Downloads)
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Try different download methods
        $Downloaded = $false
        
        # Method 1: GitHub Repository - ZIP download and extraction (PRIMARY METHOD)
        Write-Log "Versuche GitHub Repository Download..." "Cyan"
        $GitHubZipUrls = @(
            "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/archive/refs/heads/master.zip",
            "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/archive/refs/tags/v1.8.6.zip",
            "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/archive/refs/tags/v1.8.5.zip"
        )
        
        foreach ($ZipUrl in $GitHubZipUrls) {
            try {
                Write-Log "  Lade GitHub ZIP: $ZipUrl" "Yellow"
                $TempZip = Join-Path $env:TEMP "IntuneWinAppUtil_GitHub_$(Get-Random).zip"
                $TempExtract = Join-Path $env:TEMP "IntuneWinAppUtil_GitHub_Extract_$(Get-Random)"
                
                $webClient = New-Object System.Net.WebClient
                $webClient.Headers.Add("User-Agent", "PowerShell-IntuneWinAppUtil-Downloader/1.0")
                $webClient.Proxy = [System.Net.WebRequest]::DefaultWebProxy
                $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                $webClient.Timeout = 60000  # 60 seconds for ZIP files
                
                $webClient.DownloadFile($ZipUrl, $TempZip)
                
                if ((Test-Path $TempZip) -and ((Get-Item $TempZip).Length -gt 50000)) {
                    Write-Log "GitHub ZIP erfolgreich heruntergeladen, extrahiere..." "Green"
                    
                    # Extract ZIP
                    Expand-Archive -Path $TempZip -DestinationPath $TempExtract -Force
                    
                    # Search for pre-compiled EXE files in different locations
                    $SearchPaths = @(
                        "IntuneWinAppUtil.exe",
                        "*/IntuneWinAppUtil.exe", 
                        "*/bin/IntuneWinAppUtil.exe",
                        "*/Release/IntuneWinAppUtil.exe",
                        "*/x64/Release/IntuneWinAppUtil.exe",
                        "*/bin/Release/IntuneWinAppUtil.exe"
                    )
                    
                    $FoundExe = $null
                    foreach ($SearchPath in $SearchPaths) {
                        $ExeFiles = Get-ChildItem -Path $TempExtract -Filter "IntuneWinAppUtil.exe" -Recurse -ErrorAction SilentlyContinue
                        if ($ExeFiles.Count -gt 0) {
                            # Find the largest EXE file (most likely to be compiled binary)
                            $FoundExe = $ExeFiles | Sort-Object Length -Descending | Select-Object -First 1
                            break
                        }
                    }
                    
                    if ($FoundExe -and $FoundExe.Length -gt 20000) {  # Mindestens 20KB (53.9KB ist normale Größe)
                        Write-Log "Vorkompilierte EXE in GitHub gefunden: $($FoundExe.Name) ($([math]::Round($FoundExe.Length / 1KB, 2)) KB)" "Green"
                        Copy-Item $FoundExe.FullName $IntuneTool -Force
                        
                        # Validate the extracted file
                        if (Test-Path $IntuneTool) {
                            try {
                                $testResult = & $IntuneTool /? 2>&1
                                if ($LASTEXITCODE -eq 0 -or $testResult -match "IntuneWinAppUtil|Microsoft|Content Prep|Usage") {
                                    Write-Log "GitHub Download erfolgreich! Tool validiert." "Green"
                                    $Downloaded = $true
                                } else {
                                    Write-Log "GitHub EXE Validierung fehlgeschlagen" "Orange"
                                    Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
                                }
                            } catch {
                                Write-Log "GitHub EXE beschaedigt: $($_.Exception.Message)" "Orange"
                                Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
                            }
                        }
                    } else {
                        # If no large EXE found, look for any EXE files that might work
                        $AnyExeFiles = Get-ChildItem -Path $TempExtract -Filter "*.exe" -Recurse | Where-Object { $_.Length -gt 100000 }
                        if ($AnyExeFiles.Count -gt 0) {
                            $BestExe = $AnyExeFiles | Sort-Object Length -Descending | Select-Object -First 1
                            Write-Log "Alternative EXE gefunden: $($BestExe.Name) ($([math]::Round($BestExe.Length / 1KB, 2)) KB)" "Yellow"
                            Copy-Item $BestExe.FullName $IntuneTool -Force
                            
                            try {
                                $testResult = & $IntuneTool /? 2>&1
                                if ($testResult -match "IntuneWinAppUtil|Microsoft|Content Prep|Usage|Win32") {
                                    Write-Log "Alternative EXE erfolgreich validiert!" "Green"
                                    $Downloaded = $true
                                } else {
                                    Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
                                }
                            } catch {
                                Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
                            }
                        } else {
                            Write-Log "Keine verwendbare EXE-Datei in GitHub ZIP gefunden" "Orange"
                        }
                    }
                }
                
                # Cleanup
                if (Test-Path $TempZip) { Remove-Item $TempZip -Force -ErrorAction SilentlyContinue }
                if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force -ErrorAction SilentlyContinue }
                
                if ($Downloaded) { break }
                
            } catch {
                Write-Log "GitHub ZIP Download fehlgeschlagen: $($_.Exception.Message)" "Red"
                if (Test-Path $TempZip) { Remove-Item $TempZip -Force -ErrorAction SilentlyContinue }
                if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force -ErrorAction SilentlyContinue }
            }
        }
        
        # Method 2: Direct download attempts (FALLBACK)
        if (-not $Downloaded) {
            Write-Log "GitHub Download fehlgeschlagen, versuche weitere Download-Quellen..." "Orange"
            $AlternativeUrls = @(
                "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe",
                "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/releases/latest/download/IntuneWinAppUtil.exe",
                "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/releases/download/v1.8.6/IntuneWinAppUtil.exe",
                "https://github.com/MSEndpointMgr/IntuneWin32App/raw/master/Tools/IntuneWinAppUtil.exe",
                "https://aka.ms/intunewinapputildownload"
            )
        
            foreach ($Url in $AlternativeUrls) {
                try {
                    Write-Log "  Trying: $Url" 
                    
                    $webClient = New-Object System.Net.WebClient
                    $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
                    $webClient.Proxy = [System.Net.WebRequest]::DefaultWebProxy
                    $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                    $webClient.Timeout = 30000  # 30 seconds timeout
                    
                    $webClient.DownloadFile($Url, $IntuneTool)
                    
                    # Validierung der heruntergeladenen Datei (korrigierte Größe für .NET Tool)
                    if (Test-Path $IntuneTool) {
                        $FileInfo = Get-Item $IntuneTool
                        if ($FileInfo.Length -gt 20000) {  # Mindestens 20KB (53.9KB ist normale Größe)
                            # Funktionstest durchfuehren
                            try {
                                $testResult = & $IntuneTool /? 2>&1
                                if ($LASTEXITCODE -eq 0 -or $testResult -match "IntuneWinAppUtil|Microsoft|Content Prep Tool|Usage") {
                                    Write-Log "Download und Funktionstest erfolgreich von: $Url" "Green"
                                    Write-Log "Dateigroesse: $([math]::Round($FileInfo.Length / 1KB, 2)) KB" "Green"
                                    $Downloaded = $true
                                    break
                                } else {
                                    Write-Log "Datei heruntergeladen aber Funktionstest fehlgeschlagen" "Orange"
                                    Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
                                }
                            } catch {
                                Write-Log "Datei heruntergeladen aber beschaedigt: $($_.Exception.Message)" "Orange"
                                Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
                            }
                        } else {
                            Write-Log "File too small: $([math]::Round($FileInfo.Length / 1KB, 2)) KB" "Orange"
                            Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
                        }
                    }
                    
                } catch {
                    Write-Log "URL fehlgeschlagen: $($_.Exception.Message)" "Red"
                    if (Test-Path $IntuneTool) { Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue }
                }
            }
        }
        
        # Method 2: ZIP download and extraction
        if (-not $Downloaded) {
            Write-Log "Direct downloads failed, trying ZIP download and extraction..." "Orange"
            
            $ZipUrls = @(
                "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/archive/refs/heads/master.zip",
                "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/archive/refs/tags/v1.8.6.zip",
                "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/releases/latest/download/source-code.zip"
            )
            
            foreach ($ZipUrl in $ZipUrls) {
                try {
                    Write-Log "  Trying ZIP: $ZipUrl"
                    $TempZip = Join-Path $env:TEMP "IntuneWinAppUtil_$(Get-Random).zip"
                    $TempExtract = Join-Path $env:TEMP "IntuneWinAppUtil_Extract_$(Get-Random)"
                    
                    $webClient = New-Object System.Net.WebClient
                    $webClient.Headers.Add("User-Agent", "PowerShell-IntuneWinAppUtil-Downloader")
                    $webClient.Proxy = [System.Net.WebRequest]::DefaultWebProxy
                    $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                    $webClient.Timeout = 60000  # 60 seconds for larger files
                    
                    $webClient.DownloadFile($ZipUrl, $TempZip)
                    
                    if ((Test-Path $TempZip) -and ((Get-Item $TempZip).Length -gt 10000)) {
                        Write-Log "ZIP downloaded successfully, extracting..." "Green"
                        
                        # Extract and search for compiled binaries
                        Expand-Archive -Path $TempZip -DestinationPath $TempExtract -Force
                        
                        # Search for pre-compiled EXE files
                        $ExeFiles = Get-ChildItem -Path $TempExtract -Filter "IntuneWinAppUtil.exe" -Recurse -ErrorAction SilentlyContinue
                        
                        if ($ExeFiles.Count -gt 0) {
                            $FoundExe = $ExeFiles[0]
                            Copy-Item $FoundExe.FullName $IntuneTool -Force
                            Write-Log "Pre-compiled EXE found in source code!" "Green"
                            
                            # Validate the extracted file
                            if (Test-Path $IntuneTool) {
                                $FileInfo = Get-Item $IntuneTool
                                if ($FileInfo.Length -gt 20000) {  # Mindestens 20KB (53.9KB ist normale Größe)
                                    try {
                                        $testResult = & $IntuneTool /? 2>&1
                                        if ($LASTEXITCODE -eq 0 -or $testResult -match "IntuneWinAppUtil|Microsoft") {
                                            Write-Log "Extracted file validation successful!" "Green"
                                            $Downloaded = $true
                                        } else {
                                            Write-Log "Extracted file failed validation" "Orange"
                                            Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
                                        }
                                    } catch {
                                        Write-Log "Extracted file corrupted: $($_.Exception.Message)" "Orange"
                                        Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
                                    }
                                } else {
                                    Write-Log "Extracted file too small (possibly corrupted)" "Orange"
                                    Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
                                }
                            }
                        } else {
                            Write-Log "No pre-compiled EXE found in source code" "Orange"
                        }
                    }
                    
                    # Cleanup
                    if (Test-Path $TempZip) { Remove-Item $TempZip -Force -ErrorAction SilentlyContinue }
                    if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force -ErrorAction SilentlyContinue }
                    
                    if ($Downloaded) { break }
                    
                } catch {
                    Write-Log "ZIP download failed: $($_.Exception.Message)" "Red"
                    if (Test-Path $TempZip) { Remove-Item $TempZip -Force -ErrorAction SilentlyContinue }
                    if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force -ErrorAction SilentlyContinue }
                }
            }
        }
        
        # Method 3: Alternative sources with better error handling
        if (-not $Downloaded) {
            Write-Log "ZIP extraction failed, trying alternative sources..." "Orange"
            
            $AlternativeSources = @(
                "https://aka.ms/intunewinapputildownload",
                "https://archive.org/download/IntuneWinAppUtil/IntuneWinAppUtil.exe"
            )
            
            foreach ($AltUrl in $AlternativeSources) {
                try {
                    Write-Log "  Trying alternative: $AltUrl"
                    
                    # Use Invoke-WebRequest for better handling
                    Invoke-WebRequest -Uri $AltUrl -OutFile $IntuneTool -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
                    
                    if (Test-Path $IntuneTool) {
                        $FileInfo = Get-Item $IntuneTool
                        if ($FileInfo.Length -gt 50000) {  # Lower threshold for alternative sources
                            try {
                                $testResult = & $IntuneTool /? 2>&1
                                if ($testResult -match "IntuneWinAppUtil|Microsoft|Content Prep|Usage") {
                                    Write-Log "Alternative source successful: $AltUrl" "Green"
                                    $Downloaded = $true
                                    break
                                }
                            } catch {
                                Write-Log "Alternative file corrupted: $($_.Exception.Message)" "Orange"
                                Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
                            }
                        } else {
                            Write-Log "Alternative file too small" "Orange"
                            Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
                        }
                    }
                    
                } catch {
                    Write-Log "Alternative source failed: $($_.Exception.Message)" "Red"
                    if (Test-Path $IntuneTool) { Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue }
                }
            }
        }
        
        # Legacy fallback method
        if (-not $Downloaded) {
            Write-Log "All modern methods failed, trying legacy source code download..." "Orange"
            
            try {
                $SourceUrl = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/archive/refs/tags/v1.8.6.zip"
                $TempZip = Join-Path $env:TEMP "IntuneWinAppUtil_Source_$(Get-Random).zip"
                $TempExtract = Join-Path $env:TEMP "IntuneWinAppUtil_Source_Extract_$(Get-Random)"
                
                $webClient = New-Object System.Net.WebClient
                $webClient.Headers.Add("User-Agent", "PowerShell-IntuneWinAppUtil-Downloader")
                $webClient.Proxy = [System.Net.WebRequest]::DefaultWebProxy
                $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                
                Write-Log "Loading source code..."
                $webClient.DownloadFile($SourceUrl, $TempZip)
                
                if ((Test-Path $TempZip) -and ((Get-Item $TempZip).Length -gt 10000)) {
                    Write-Log "Source code downloaded successfully" "Green"
                    
                    # Extract and search for pre-compiled binaries
                    Expand-Archive -Path $TempZip -DestinationPath $TempExtract -Force
                    
                    # Search for pre-compiled EXE files in source
                    $ExeFiles = Get-ChildItem -Path $TempExtract -Filter "IntuneWinAppUtil.exe" -Recurse
                    if ($ExeFiles.Count -gt 0) {
                        Copy-Item $ExeFiles[0].FullName $IntuneTool -Force
                        Write-Log "Vorkompilierte EXE aus Source-Code gefunden!" "Green"
                        $Downloaded = $true
                    } else {
                        Write-Log "Keine vorkompilierte EXE im Source-Code gefunden" "Orange"
                    }
                }
                
                # Aufraeumen
                if (Test-Path $TempZip) { Remove-Item $TempZip -Force -ErrorAction SilentlyContinue }
                if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force -ErrorAction SilentlyContinue }
                
            } catch {
                Write-Log "Source-Code Download fehlgeschlagen: $($_.Exception.Message)" "Red"
            }
        }
        
        # Erfolg pruefen
        if ($Downloaded -and (Test-Path $IntuneTool)) {
            $FileInfo = Get-Item $IntuneTool
            if ($FileInfo.Length -gt 20000) { # Mindestens 20KB (53.9KB ist normale Größe)
                Write-Log "Download erfolgreich! Dateigroeße: $([math]::Round($FileInfo.Length / 1MB, 2)) MB" "Green"
                
                # Version pruefen falls moeglich
                try {
                    $VersionInfo = & $IntuneTool -v 2>&1
                    if ($VersionInfo -match "(\d+\.\d+\.\d+)") {
                        Write-Log "Tool-Version: $($Matches[1])" "Green"
                    }
                } catch {
                    # Version-Check fehlgeschlagen, aber das ist ok
                }
                
                return $true
            } else {
                Write-Log "Heruntergeladene Datei zu klein (moeglicherweise korrupt)" "Red"
                Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Fallback: Detaillierte manuelle Anleitung
        Write-Log "Alle automatischen Download-Methoden fehlgeschlagen!" "Red"
        Write-Log "" 
        Write-Log "=== MANUELLE INSTALLATION ===" "Orange"
        Write-Log "Microsoft stellt das Tool nicht mehr direkt zum Download bereit." "Orange"
        Write-Log "" 
        Write-Log "BESTE OPTION - Intune Admin Center (EMPFOHLEN):" "Yellow"
        Write-Log "1. Loggen Sie sich in https://endpoint.microsoft.com ein" "Yellow"
        Write-Log "2. Gehen Sie zu Apps > Windows > Hinzufuegen > Win32-App" "Yellow"
        Write-Log "3. Klicken Sie auf 'App-Paketdatei auswaehlen'" "Yellow"
        Write-Log "4. Laden Sie das Tool vom dort bereitgestellten Link herunter" "Yellow"
        Write-Log "" 
        Write-Log "ALTERNATIVE OPTIONEN:" "Yellow"
        Write-Log "1. Suchen Sie nach 'Microsoft Win32 Content Prep Tool'" "Yellow"
        Write-Log "2. Pruefen Sie IT-Community Seiten (z.B. TechNet)" "Yellow"
        Write-Log "3. Fragen Sie Ihren IT-Administrator" "Yellow"
        Write-Log "" 
        Write-Log "WICHTIG: Datei muss mindestens 20 KB gross sein!" "Red"
        Write-Log "Die normale Groesse betraegt etwa 53.9 KB fuer .NET Tools." "Red"
        Write-Log "" 
        Write-Log "Speichern Sie die Datei unter: $ToolsPath" "Yellow"
        Write-Log "===============================" "Orange"
        
        [System.Windows.Forms.MessageBox]::Show(
            "Automatischer Download fehlgeschlagen!`n`n" +
            "MANUELLE INSTALLATION ERFORDERLICH:`n`n" +
            "BESTE OPTION - Intune Admin Center:`n" +
            "• Gehen Sie zu https://endpoint.microsoft.com`n" +
            "• Apps > Windows > Hinzufuegen > Win32-App`n" +
            "• Klicken Sie auf 'App-Paketdatei auswaehlen'`n" +
            "• Laden Sie das Tool vom bereitgestellten Link herunter`n`n" +
            "WICHTIG: Datei muss mindestens 20 KB gross sein!`n" +
            "Die normale Groesse betraegt etwa 53.9 KB.`n`n" +
            "Speichern Sie IntuneWinAppUtil.exe in:`n$ToolsPath",
            "Download-Fehler - Manuelle Installation erforderlich",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return $false
        
    } catch {
        Write-Log "Kritischer Fehler beim Download: $($_.Exception.Message)" "Red"
        [System.Windows.Forms.MessageBox]::Show(
            "Kritischer Fehler beim Download!`n`nFehler: $($_.Exception.Message)`n`n" +
            "Bitte laden Sie IntuneWinAppUtil.exe manuell herunter von:`n" +
            "https://aka.ms/win32contentpreptool`n`n" +
            "Und speichern Sie es unter: $ToolsPath",
            "Kritischer Download-Fehler",
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

function New-IntuneWinAppPackage {
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
    
    # Pfade fuer das Tool bereinigen und absolut machen
    $ResolvedSourceFolder = Resolve-Path -LiteralPath $SourceFolder
    $ResolvedOutputFolder = Resolve-Path -LiteralPath $OutputFolder
    $ResolvedIntuneTool = Resolve-Path -LiteralPath $IntuneTool

    Write-Log "Tool-Befehl: `"$($ResolvedIntuneTool.Path)`" -c `"$($ResolvedSourceFolder.Path)`" -s `"install.cmd`" -o `"$($ResolvedOutputFolder.Path)`"" "Gray"
    
    # Detaillierte Parameter-Validierung
    Write-Log "Validiere Parameter..." "Blue"
    Write-Log "   Source-Ordner: $SourceFolder (Existiert: $(Test-Path $SourceFolder))" "Gray"
    Write-Log "   Setup-Datei: install.cmd (Existiert: $(Test-Path "$SourceFolder\install.cmd"))" "Gray"
    Write-Log "   Output-Ordner: $OutputFolder (Existiert: $(Test-Path $OutputFolder))" "Gray"
    Write-Log "   IntuneWinAppUtil: $($ResolvedIntuneTool.Path) (Existiert: $(Test-Path $ResolvedIntuneTool.Path))" "Gray"
    
    # Teste Tool-Funktionalitaet
    try {
        Write-Log "Teste Tool-Version..." "Blue"
        & $IntuneTool -h 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Tool ist funktionsfaehig" "Green"
        } else {
            Write-Log "WARNUNG: Tool gibt Exit-Code $LASTEXITCODE zurueck" "Orange"
        }
    } catch {
        Write-Log "WARNUNG: Tool-Test fehlgeschlagen: $($_.Exception.Message)" "Orange"
    }
    
    # Tool direkt mit erweiterter Fehlerbehandlung ausfuehren
    try {
        Write-Log "=== ERWEITERTE TOOL-DIAGNOSE ===" "Blue"
        
        # Tool-Befehl zusammenstellen und protokollieren
        $ToolArgs = @("-c", "`"$($ResolvedSourceFolder.Path)`"", "-s", "`"install.cmd`"", "-o", "`"$($ResolvedOutputFolder.Path)`"")
        Write-Log "Fuehre aus: $($ResolvedIntuneTool.Path) $($ToolArgs -join ' ')" "Blue"
        
        # Process-Objekt fuer bessere Kontrolle erstellen
        $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
        $ProcessInfo.FileName = $ResolvedIntuneTool.Path
        $ProcessInfo.Arguments = $ToolArgs -join ' '
        $ProcessInfo.RedirectStandardOutput = $true
        $ProcessInfo.RedirectStandardError = $true
        $ProcessInfo.UseShellExecute = $false
        $ProcessInfo.CreateNoWindow = $true
        $ProcessInfo.WorkingDirectory = $ScriptPath
        
        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo = $ProcessInfo
        
        # Ausgabe-Handler
        $StdOut = New-Object System.Text.StringBuilder
        $StdErr = New-Object System.Text.StringBuilder
        
        $Process.add_OutputDataReceived({
            if ($_.Data) {
                [void]$StdOut.AppendLine($_.Data)
            }
        })
        
        $Process.add_ErrorDataReceived({
            if ($_.Data) {
                [void]$StdErr.AppendLine($_.Data)
            }
        })
        
        # Prozess starten
        Write-Log "Starte IntuneWinAppUtil.exe..." "Blue"
        $Process.Start()
        $Process.BeginOutputReadLine()
        $Process.BeginErrorReadLine()
        
        # Timeout von 3 Minuten fuer groessere Apps
        $TimeoutMs = 180000
        if (-not $Process.WaitForExit($TimeoutMs)) {
            Write-Log "TIMEOUT: Tool reagiert nach 3 Minuten nicht - beende Prozess" "Red"
            $Process.Kill()
            $Process.WaitForExit()
            throw "Tool-Timeout nach 3 Minuten"
        }
        
        $ExitCode = $Process.ExitCode
        $Process.Close()
        
        # Ausgabe protokollieren
        $OutputText = $StdOut.ToString().Trim()
        $ErrorText = $StdErr.ToString().Trim()
        
        Write-Log "=== TOOL-AUSGABE-ANALYSE ===" "Blue"
        Write-Log "Exit-Code: $ExitCode" "Blue"
        
        if ($OutputText) {
            Write-Log "Standard-Ausgabe:" "Blue"
            $OutputText -split "`n" | ForEach-Object {
                if ($_.Trim()) { Write-Log "  $($_.Trim())" "Gray" }
            }
        } else {
            Write-Log "Keine Standard-Ausgabe erhalten" "Orange"
        }
        
        if ($ErrorText) {
            Write-Log "Fehler-Ausgabe:" "Red"
            $ErrorText -split "`n" | ForEach-Object {
                if ($_.Trim()) { Write-Log "  $($_.Trim())" "Red" }
            }
        } else {
            Write-Log "Keine Fehler-Ausgabe erhalten" "Green"
        }
        
        Write-Log "=========================" "Blue"
        
        # Erfolg basierend auf Exit-Code pruefen
        if ($ExitCode -ne 0) {
            Write-Log "Tool beendet mit Fehler-Code: $ExitCode" "Red"
            
            # Haeufige Exit-Codes interpretieren
            $errorMsg = switch ($ExitCode) {
                1 { "Allgemeiner Anwendungsfehler - pruefen Sie Berechtigungen und Parameter" }
                2 { "Ungueltige Parameter oder Dateien nicht gefunden" }
                3 { "Zugriffsberechtigung verweigert - fuehren Sie als Administrator aus" }
                5 { "Ausgabeordner nicht beschreibbar" }
                87 { "Ungueltige Parameter-Syntax" }
                -1 { "Schwerwiegender interner Fehler" }
                default { "Unbekannter Exit-Code: $ExitCode" }
            }
            Write-Log "Fehler-Details: $errorMsg" "Red"
        }
        
    } catch {
        Write-Log "KRITISCHER FEHLER beim Tool-Aufruf: $($_.Exception.Message)" "Red"
        Write-Log "Exception-Typ: $($_.Exception.GetType().Name)" "Red"
        
        # Progress Bar ausblenden
        $elements.progressBar.Visibility = "Collapsed"
        $elements.progressBar.IsIndeterminate = $false
        return
    }
    
    # Progress Bar ausblenden
    $elements.progressBar.Visibility = "Collapsed"
    $elements.progressBar.IsIndeterminate = $false
    
    # Pruefen ob .intunewin erfolgreich erstellt wurde
    Write-Log "=== ERFOLGS-KONTROLLE ===" "Blue"
    Write-Log "Pruefe Ausgabe-Ordner: $ResolvedOutputFolder" "Blue"
    Start-Sleep -Seconds 2  # Warten fuer Dateisystem-Sync
    
    $IntunewinFile = Get-ChildItem -Path $ResolvedOutputFolder.Path -Filter "*.intunewin" -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if ($IntunewinFile -and (Test-Path $IntunewinFile.FullName)) {
        Write-Log ".intunewin Paket erfolgreich erstellt!" "Green"
        Write-Log "Datei: $($IntunewinFile.Name)" "Green"
        Write-Log "Groesse: $([math]::Round($IntunewinFile.Length / 1KB, 2)) KB" "Green"
        Write-Log "Pfad: $($IntunewinFile.FullName)" "Green"
    } else {
        Write-Log "FEHLER: Keine .intunewin Datei im Ausgabe-Ordner gefunden!" "Red"
        
        # Erweiterte Diagnose
        Write-Log "=== DETAILLIERTE ORDNER-DIAGNOSE ===" "Orange"
        Write-Log "Ausgabe-Ordner Inhalt ($OutputFolder):" "Orange"
        
        try {
            $OutputContents = Get-ChildItem -Path $OutputFolder -Force -ErrorAction SilentlyContinue
            if ($OutputContents) {
                foreach ($Item in $OutputContents) {
                    $Size = if ($Item.PSIsContainer) { "[Ordner]" } else { "$([math]::Round($Item.Length / 1KB, 2)) KB" }
                    $Type = if ($Item.PSIsContainer) { "[Ordner]" } else { "[Datei]" }
                    Write-Log "  $Type $($Item.Name) ($Size)" "Orange"
                }
            } else {
                Write-Log "  Ordner ist vollstaendig leer!" "Red"
            }
        } catch {
            Write-Log "  Fehler beim Lesen des Ausgabe-Ordners: $($_.Exception.Message)" "Red"
        }
        
        Write-Log "Quell-Ordner Inhalt ($SourceFolder):" "Orange"
        try {
            $SourceContents = Get-ChildItem -Path $SourceFolder -Force -ErrorAction SilentlyContinue
            foreach ($Item in $SourceContents) {
                $Size = if ($Item.PSIsContainer) { "[Ordner]" } else { "$([math]::Round($Item.Length / 1KB, 2)) KB" }
                $Type = if ($Item.PSIsContainer) { "[Ordner]" } else { "[Datei]" }
                Write-Log "  $Type $($Item.Name) ($Size)" "Orange"
            }
        } catch {
            Write-Log "  Fehler beim Lesen des Quell-Ordners: $($_.Exception.Message)" "Red"
        }
        
        Write-Log "====================================" "Orange"
        
        # Umfassende Troubleshooting-Tipps
        Write-Log "TROUBLESHOOTING-ANLEITUNG:" "Yellow"
        Write-Log "1. PARAMETER PRUEFEN:" "Yellow"
        Write-Log "   • install.cmd existiert und ist gueltig" "Yellow"
        Write-Log "   • EXE-Datei ist im Quell-Ordner vorhanden" "Yellow"
        Write-Log "   • Quell- und Ausgabe-Ordner sind unterschiedlich" "Yellow"
        Write-Log "" 
        Write-Log "2. BERECHTIGUNGEN PRUEFEN:" "Yellow"
        Write-Log "   • Als Administrator ausfuehren" "Yellow"
        Write-Log "   • Schreibberechtigung im Ausgabe-Ordner" "Yellow"
        Write-Log "   • Keine Dateisperrung durch andere Programme" "Yellow"
        Write-Log "" 
        Write-Log "3. ANTIVIRUS / SICHERHEIT:" "Yellow"
        Write-Log "   • Windows Defender Ausnahme hinzufuegen" "Yellow"
        Write-Log "   • Ordner temporaer von Antivirus ausschliessen" "Yellow"
        Write-Log "   • UAC (Benutzerkontensteuerung) pruefen" "Yellow"
        Write-Log "" 
        Write-Log "4. MANUELLER TEST:" "Yellow"
        Write-Log "   Probieren Sie diesen Befehl in der Kommandozeile:" "Yellow"
        Write-Log "   cd /d `"$ScriptPath`"" "Yellow"
        Write-Log "   `"$IntuneTool`" -c `"$SourceFolder`" -s `"install.cmd`" -o `"$OutputFolder`"" "Yellow"
        Write-Log "" 
        Write-Log "5. ALTERNATIVE LOESUNGEN:" "Yellow"
        Write-Log "   • Versuchen Sie einen anderen App-Ordner" "Yellow"
        Write-Log "   • Verwenden Sie kuerzere Pfadnamen (keine Sonderzeichen)" "Yellow"
        Write-Log "   • Kopieren Sie Dateien in einen lokalen Ordner (nicht Netzwerk)" "Yellow"
        Write-Log "   • Neustart des Computers falls notwendig" "Yellow"
        
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
    $Meta | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $ResolvedOutputFolder.Path "metadata.json")
    
    Write-Log "Metadaten gespeichert in: metadata.json" "Green"
    Write-Log "Verpackung abgeschlossen!" "Green"
    
    # Zusammenfassung
    Write-Log "`nZusammenfassung fuer Intune:" "Blue"
    Write-Log "====================================="
    Write-Log "App-Name: $AppName"
    Write-Log "Install-Befehl: install.cmd"
    Write-Log "Uninstall-Befehl: uninstall.cmd"
    Write-Log "Rueckgabecodes: 0 (Erfolg)$(if ($ExitCode -eq 3010) { ', 3010 (Neustart erforderlich)' } else { '' })"
    Write-Log "====================================="
    
    # Ausgabeordner automatisch oeffnen
    Write-Log "Oeffne Ausgabeordner: $($ResolvedOutputFolder.Path)" "Blue"
    Start-Process -FilePath "explorer.exe" -ArgumentList $ResolvedOutputFolder.Path
}

# GUI initialisieren und anzeigen
Initialize-GUI
$window.ShowDialog() | Out-Null
