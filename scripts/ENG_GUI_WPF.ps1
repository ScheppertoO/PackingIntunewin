
# IntuneWin App Packaging Tool - WPF GUI
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Base paths relative to script folder
$ScriptPath = $PSScriptRoot
$BaseInputPath = Join-Path $ScriptPath "apps"
$BaseOutputPath = Join-Path $ScriptPath "IntunewinApps"
$ToolsPath = Join-Path $ScriptPath "IntunewinApps\tools"
$IntuneTool = Join-Path $ToolsPath "IntuneWinAppUtil.exe"
$GitHubRepo = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool"

# XAML definition for the GUI
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
        <GroupBox Grid.Row="1" Header="App Selection" Margin="0,10,0,10" Padding="10">
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
                <Button Grid.Row="0" Grid.Column="1" x:Name="btnRefreshApps">Refresh</Button>
                
                <Button Grid.Row="1" Grid.Column="0" Grid.ColumnSpan="2" x:Name="btnOpenAppFolder" 
                        Margin="0,10,0,0" HorizontalAlignment="Left">Open Apps Folder</Button>
            </Grid>
        </GroupBox>
        
        <!-- Configuration -->
        <GroupBox Grid.Row="2" Header="Configuration" Margin="0,0,0,10" Padding="10">
            <StackPanel>
                <CheckBox x:Name="chkRebootRequired">Reboot required after installation</CheckBox>
            </StackPanel>
        </GroupBox>
        
        <!-- Actions -->
        <GroupBox Grid.Row="3" Header="Actions" Margin="0,0,0,10" Padding="10">
            <StackPanel Orientation="Horizontal">
                <Button x:Name="btnInitialize" ToolTip="Initialize folder structure">Initialize</Button>
                <Button x:Name="btnCheckTool" ToolTip="Check/download IntuneWinAppUtil.exe">Check Tool</Button>
                <Button x:Name="btnCreatePackage" IsEnabled="False" Background="LightGreen">Create Package</Button>
                <Button x:Name="btnOpenOutputFolder" IsEnabled="False">Open Output Folder</Button>
            </StackPanel>
        </GroupBox>
        
        <!-- Status -->
        <GroupBox Grid.Row="4" Header="Status" Margin="0,0,0,10" Padding="10">
            <StackPanel>
                <TextBlock x:Name="lblStatus" Text="Ready. Please select an app." TextWrapping="Wrap"/>
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
            <Button x:Name="btnExit" Width="100">Exit</Button>
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

# Helper functions for the GUI
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
    
    # Update status label
    $elements.lblStatus.Dispatcher.Invoke(
        [action]{
            $elements.lblStatus.Text = $Message
            $elements.lblStatus.Foreground = $Color
        }
    )
}

function Initialize-GUI {
    # Display working directory
    $elements.lblWorkingDir.Text = "Working Directory: $ScriptPath"
    
    # Event handlers for buttons
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
                Write-Log "Output folder does not exist yet: $outputFolder" "Red"
            }
        }
    })
    
    # Monitor ComboBox changes
    $elements.cboAppFolder.Add_SelectionChanged({
        $selectedApp = $elements.cboAppFolder.SelectedItem
        if ($selectedApp) {
            $elements.btnCreatePackage.IsEnabled = $true
            $elements.btnOpenOutputFolder.IsEnabled = $true
            $sourceFolder = Join-Path $BaseInputPath $selectedApp
            
            # Check for EXE files
            $exeFiles = Get-ChildItem -Path $sourceFolder -Filter *.exe -ErrorAction SilentlyContinue
            if ($exeFiles.Count -eq 1) {
                Write-Log "App selected: $selectedApp (with $($exeFiles[0].Name))" "Blue"
            } 
            elseif ($exeFiles.Count -eq 0) {
                Write-Log "WARNING: No EXE files found in $selectedApp!" "Red"
                $elements.btnCreatePackage.IsEnabled = $false
            }
            else {
                Write-Log "WARNING: Multiple EXE files found in $selectedApp. First will be used: $($exeFiles[0].Name)" "Orange"
            }
        }
        else {
            $elements.btnCreatePackage.IsEnabled = $false
            $elements.btnOpenOutputFolder.IsEnabled = $false
        }
    })
    
    # Load app list initially
    Refresh-AppList
    
    Write-Log "IntuneWin App Packaging Tool started" "Blue"
}

function Refresh-AppList {
    $elements.cboAppFolder.Items.Clear()
    
    # Check if base input path exists
    if (-not (Test-Path $BaseInputPath)) {
        Write-Log "Apps folder not found. Please initialize folder structure." "Red"
        return
    }
    
    # List available app folders
    $appFolders = Get-ChildItem -Path $BaseInputPath -Directory | Sort-Object Name
    
    if ($appFolders.Count -gt 0) {
        foreach ($folder in $appFolders) {
            $elements.cboAppFolder.Items.Add($folder.Name)
        }
        Write-Log "$($appFolders.Count) app folders found" "Green"
    }
    else {
        Write-Log "No app folders found. Please create folders with EXE files in the 'apps' directory." "Orange"
    }
}

function Initialize-FoldersGUI {
    Write-Log "Initializing folder structure..." "Blue"
    
    # Create required folders
    $RequiredFolders = @($BaseInputPath, $BaseOutputPath, $ToolsPath)
    
    foreach ($Folder in $RequiredFolders) {
        if (-not (Test-Path $Folder)) {
            Write-Log "   Creating: $($Folder -replace [regex]::Escape($ScriptPath), '.')" 
            New-Item -ItemType Directory -Force -Path $Folder | Out-Null
        }
    }
    
    Write-Log "Folder structure successfully initialized" "Green"
    Write-Log "   Apps: $(Split-Path $BaseInputPath -Leaf)"
    Write-Log "   Output: $(Split-Path $BaseOutputPath -Leaf)"
    Write-Log "   Tools: $(Split-Path $ToolsPath -Leaf)"
    
    # Update app list
    Refresh-AppList
}

function Test-IntuneWinAppUtilGUI {
    Write-Log "Checking IntuneWinAppUtil.exe..." "Blue"
    
    # Create tools folder if not present
    if (-not (Test-Path $ToolsPath)) {
        Write-Log "Creating tools folder: $ToolsPath"
        New-Item -ItemType Directory -Force -Path $ToolsPath | Out-Null
    }
    
    # Check if IntuneWinAppUtil.exe exists and works
    if (Test-Path $IntuneTool) {
        Write-Log "IntuneWinAppUtil.exe found: $IntuneTool" "Green"
        
        # Check file integrity
        try {
            $FileInfo = Get-Item $IntuneTool
            if ($FileInfo.Length -lt 100000) {
                Write-Log "WARNING: File too small ($([math]::Round($FileInfo.Length / 1KB, 2)) KB), possibly corrupted" "Orange"
                Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
            } else {
                # Perform function test
                try {
                    $testResult = & $IntuneTool /? 2>&1
                    if ($LASTEXITCODE -eq 0 -or $testResult -match "IntuneWinAppUtil|Microsoft") {
                        Write-Log "Tool function test successful" "Green"
                        return $true
                    } else {
                        Write-Log "WARNING: Tool function test failed, downloading again" "Orange"
                        Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
                    }
                } catch {
                    Write-Log "WARNING: Tool corrupted ($($_.Exception.Message)), downloading again" "Orange"
                    Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
                }
            }
        } catch {
            Write-Log "WARNING: Cannot read file ($($_.Exception.Message)), downloading again" "Orange"
            Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
        }
    }
    
    Write-Log "Downloading IntuneWinAppUtil.exe..." "Orange"
    
    try {
        # Show progress bar
        $elements.progressBar.Visibility = "Visible"
        $elements.progressBar.IsIndeterminate = $true
        
        # Enable TLS 1.2 (required for modern downloads)
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Try different download methods
        $Downloaded = $false
        
        # Method 1: Aktuelle und vertrauenswuerdige Download-Quellen
        Write-Log "Versuche vertrauenswuerdige Download-Quellen..."
        $AlternativeUrls = @(
            "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/releases/download/v1.8.6/IntuneWinAppUtil.exe",
            "https://github.com/MSEndpointMgr/IntuneWin32App/raw/master/Tools/IntuneWinAppUtil.exe",
            "https://download.microsoft.com/download/8/b/e/8be61b72-ae5a-4cd9-8b01-6f6c8b8e4f8e/IntuneWinAppUtil.exe",
            "https://archive.org/download/IntuneWinAppUtil/IntuneWinAppUtil.exe",
            "https://aka.ms/intunewinapputildownload"
        )
        
        foreach ($Url in $AlternativeUrls) {
            try {
                Write-Log "  Trying: $Url" 
                
                $webClient = New-Object System.Net.WebClient
                $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
                $webClient.Proxy = [System.Net.WebRequest]::DefaultWebProxy
                $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                
                $webClient.DownloadFile($Url, $IntuneTool)
                
                # Erweiterte Validierung der heruntergeladenen Datei
                if (Test-Path $IntuneTool) {
                    $FileInfo = Get-Item $IntuneTool
                    if ($FileInfo.Length -gt 100000) {
                        # Funktionstest durchfuehren
                        try {
                            $testResult = & $IntuneTool /? 2>&1
                            if ($LASTEXITCODE -eq 0 -or $testResult -match "IntuneWinAppUtil|Microsoft|Content Prep Tool") {
                                Write-Log "Download und Funktionstest successful von: $Url" "Green"
                                Write-Log "DateiSize: $([math]::Round($FileInfo.Length / 1MB, 2)) MB" "Green"
                                $Downloaded = $true
                                break
                            } else {
                                Write-Log "Datei heruntergeladen aber Funktionstest failed" "Orange"
                                Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
                            }
                        } catch {
                            Write-Log "Datei heruntergeladen aber beschaedigt: $($_.Exception.Message)" "Orange"
                            Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
                        }
                    } else {
                        Write-Log "Datei zu klein: $([math]::Round($FileInfo.Length / 1KB, 2)) KB" "Orange"
                        Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
                    }
                }
                
            } catch {
                Write-Log "URL failed: $($_.Exception.Message)" "Red"
                if (Test-Path $IntuneTool) { Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue }
            }
        }
        
        # Method 2: Fallback to GitHub Source und local compilation (falls .NET available)
        if (-not $Downloaded) {
            Write-Log "Alle direkten Downloads failed, versuche Source code download..." "Orange"
            
            try {
                $SourceUrl = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/archive/refs/tags/v1.8.6.zip"
                $TempZip = Join-Path $env:TEMP "IntuneWinAppUtil_Source_$(Get-Random).zip"
                $TempExtract = Join-Path $env:TEMP "IntuneWinAppUtil_Source_Extract_$(Get-Random)"
                
                $webClient = New-Object System.Net.WebClient
                $webClient.Headers.Add("User-Agent", "PowerShell-IntuneWinAppUtil-Downloader")
                $webClient.Proxy = [System.Net.WebRequest]::DefaultWebProxy
                $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                
                Write-Log "Lade Source-Code herunter..."
                $webClient.DownloadFile($SourceUrl, $TempZip)
                
                if ((Test-Path $TempZip) -and ((Get-Item $TempZip).Length -gt 10000)) {
                    Write-Log "Source-Code successful heruntergeladen" "Green"
                    
                    # Extract and search for precompiled binaries
                    Expand-Archive -Path $TempZip -DestinationPath $TempExtract -Force
                    
                    # Suche nach bereits kompilierten EXE-Dateien im Source
                    $ExeFiles = Get-ChildItem -Path $TempExtract -Filter "IntuneWinAppUtil.exe" -Recurse
                    if ($ExeFiles.Count -gt 0) {
                        Copy-Item $ExeFiles[0].FullName $IntuneTool -Force
                        Write-Log "Precompiled EXE found in source code!" "Green"
                        $Downloaded = $true
                    } else {
                        Write-Log "No precompiled EXE found in source code" "Orange"
                    }
                }
                
                # Cleanup
                if (Test-Path $TempZip) { Remove-Item $TempZip -Force -ErrorAction SilentlyContinue }
                if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force -ErrorAction SilentlyContinue }
                
            } catch {
                Write-Log "Source code download failed: $($_.Exception.Message)" "Red"
            }
        }
        
        # Erfolg pruefen
        if ($Downloaded -and (Test-Path $IntuneTool)) {
            $FileInfo = Get-Item $IntuneTool
            if ($FileInfo.Length -gt 100000) { # Mindestens 100KB
                Write-Log "Download successful! File size: $([math]::Round($FileInfo.Length / 1MB, 2)) MB" "Green"
                
                # Version pruefen falls moeglich
                try {
                    $VersionInfo = & $IntuneTool -v 2>&1
                    if ($VersionInfo -match "(\d+\.\d+\.\d+)") {
                        Write-Log "Tool version: $($Matches[1])" "Green"
                    }
                } catch {
                    # Version-Check failed, aber das ist ok
                }
                
                return $true
            } else {
                Write-Log "Downloaded file too small (possibly corrupt)" "Red"
                Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Fallback: Detaillierte manuelle Anleitung
        Write-Log "All automatic download methods failed!" "Red"
        Write-Log "" 
        Write-Log "=== MANUAL INSTALLATION ===" "Orange"
        Write-Log "The tool is unfortunately no longer directly available from GitHub." "Orange"
        Write-Log "" 
        Write-Log "OPTION 1 - Microsoft Download Center:" "Yellow"
        Write-Log "1. Visit: https://aka.ms/win32contentpreptool" "Yellow"
        Write-Log "2. Or search for 'Microsoft Win32 Content Prep Tool'" "Yellow"
        Write-Log "" 
        Write-Log "OPTION 2 - Alternative Sources:" "Yellow"
        Write-Log "1. Search the internet for 'IntuneWinAppUtil.exe download'" "Yellow"
        Write-Log "2. Check PowerShell Gallery or Chocolatey" "Yellow"
        Write-Log "" 
        Write-Log "OPTION 3 - From existing Intune Admin Center:" "Yellow"
        Write-Log "1. Log in to https://endpoint.microsoft.com ein" "Yellow"
        Write-Log "2. Go to Apps > Windows > Add > Win32 app" "Yellow"
        Write-Log "3. Download the tool from there" "Yellow"
        Write-Log "" 
        Write-Log "Save the file to: $ToolsPath" "Yellow"
        Write-Log "===============================" "Orange"
        
        [System.Windows.Forms.MessageBox]::Show(
            "Automatic download failed!`n`n" +
            "MANUAL INSTALLATION REQUIRED:`n`n" +
            "OPTION 1 - Microsoft Download:`n" +
            "• Visit: https://aka.ms/win32contentpreptool`n" +
            "• Or search for 'Microsoft Win32 Content Prep Tool'`n`n" +
            "OPTION 2 - Intune Admin Center:`n" +
            "• Gehen Sie zu https://endpoint.microsoft.com`n" +
            "• Apps > Windows > Add > Win32 app`n" +
            "• Download the tool from there`n`n" +
            "Save IntuneWinAppUtil.exe to:`n$ToolsPath",
            "Download Error - MANUAL INSTALLATION REQUIRED",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return $false
        
    } catch {
        Write-Log "Critical error during download: $($_.Exception.Message)" "Red"
        [System.Windows.Forms.MessageBox]::Show(
            "Kritischer Fehler beim Download!`n`nERROR: $($_.Exception.Message)`n`n" +
            "Please download IntuneWinAppUtil.exe manually von:`n" +
            "https://aka.ms/win32contentpreptool`n`n" +
            "And save it to: $ToolsPath",
            "Kritischer Download Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return $false
    } finally {
        # Hide progress bar
        $elements.progressBar.Visibility = "Collapsed"
        $elements.progressBar.IsIndeterminate = $false
    }
}

function Get-UninstallInfoGUI {
    param(
        [string]$AppName,
        [string]$ExePath
    )
    
    Write-Log "Searching for uninstall information fuer '$AppName'..." "Blue"
    
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
                    Write-Log "Found: $($Program.DisplayName)" "Green"
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

function Test-ExeUninstallparameterssGUI {
    param([string]$ExePath)
    
    Write-Log "Analyzing EXE fuer Deinstallationsparameters..." "Blue"
    
    # Dateiname-basierte Heuristik
    Write-Log "Analyzing Dateiname..."
    $FileName = [System.IO.Path]::GetFileNameWithoutExtension($ExePath).ToLower()
    
    # Installer-Typ aus Dateiname ableiten
    if ($FileName -like "*setup*" -or $FileName -like "*install*") {
        Write-Log "Setup/Installer detected aus Dateiname" "Green"
        
        if ($FileName -like "*nsis*") {
            return "/S"
        } elseif ($FileName -like "*inno*") {
            return "/SILENT"
        } else {
            return "/uninstall /silent"
        }
    } elseif ($FileName -like "*msi*") {
        Write-Log "MSI-bezogen detected aus Dateiname" "Green"
        return "/x /quiet"
    }
    
    # Sichere Fallback-Heuristik
    Write-Log "Keine spezifischen parameters detected, verwende Standard-Heuristik" "Orange"
    
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
    
    Write-Log "Recommended parameters: $SelectedParams" "Orange"
    return $SelectedParams
}

function Create-IntuneWinAppPackage {
    # Ausgewaehlte App holen
    $InputFolder = $elements.cboAppFolder.SelectedItem
    
    if (-not $InputFolder) {
        Write-Log "Please select an app!" "Red"
        return
    }
    
    # Pfade definieren
    $SourceFolder = Join-Path $BaseInputPath $InputFolder
    $OutputFolder = Join-Path $BaseOutputPath $InputFolder
    
    # Pruefen, ob der Ordner existiert
    if (-not (Test-Path $SourceFolder)) {
        Write-Log "App-Ordner '$InputFolder' not found!" "Red"
        return
    }
    
    # Pruefe Tool-availablekeit
    if (-not (Test-Path $IntuneTool)) {
        $toolResult = Test-IntuneWinAppUtilGUI
        if (-not $toolResult) {
            Write-Log "Required tool missing: IntuneWinAppUtil.exe" "Red"
            return
        }
    }
    
    # Pruefen, ob eine .exe vorhanden ist
    $ExeFiles = Get-ChildItem -Path $SourceFolder -Filter *.exe
    if ($ExeFiles.Count -eq 0) {
        Write-Log "Keine .exe in directory '$SourceFolder' gefunden!" "Red"
        return
    }
    
    $ExeName = $ExeFiles[0].Name
    $ExePath = $ExeFiles[0].FullName
    $AppName = [System.IO.Path]::GetFileNameWithoutExtension($ExeName)
    
    Write-Log "Starting packaging for $AppName..." "Blue"
    
    # Reboot-Einstellung pruefen
    $RebootRequired = $elements.chkRebootRequired.IsChecked
    if ($RebootRequired) {
        $ExitCode = 3010  # Soft reboot required
        Write-Log "Reboot after installation will be required (Exit Code: 3010)" "Orange"
    } else {
        $ExitCode = 0     # Normaler Erfolg
        Write-Log "No reboot required (Exit Code: 0)" "Green"
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
        Write-Log "Kein Registry-Eintrag gefunden, teste EXE-parameters..." "Orange"
        $UninstallParams = Test-ExeUninstallparameterssGUI -ExePath $ExePath
        $UninstallCommand = "$ExeName $UninstallParams"
        Write-Log "Verwende EXE mit parametersn: $UninstallCommand" "Orange"
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
    Write-Log "install.cmd created" "Green"
    
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
    Write-Log "uninstall.cmd created" "Green"
    
    # Show progress bar
    $elements.progressBar.Visibility = "Visible"
    $elements.progressBar.IsIndeterminate = $true
    
    # .intunewin erstellen (im Hintergrund)
    Write-Log "Creating .intunewin package (this may take a moment)..." "Blue"
    Write-Log "Tool command: $IntuneTool -c `"$SourceFolder`" -s `"install.cmd`" -o `"$OutputFolder`"" "Gray"
    
    # Detaillierte parameters-Validierung
    Write-Log "Validating parameterss..." "Blue"
    Write-Log "   Source folder: $SourceFolder (Exists: $(Test-Path $SourceFolder))" "Gray"
    Write-Log "   Setup file: install.cmd (Exists: $(Test-Path "$SourceFolder\install.cmd"))" "Gray"
    Write-Log "   Output folder: $OutputFolder (Exists: $(Test-Path $OutputFolder))" "Gray"
    Write-Log "   IntuneWinAppUtil: $IntuneTool (Exists: $(Test-Path $IntuneTool))" "Gray"
    
    # Teste Tool-Funktionalitaet
    try {
        Write-Log "Testing tool version..." "Blue"
        $versionResult = & $IntuneTool -h 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Tool is functional" "Green"
        } else {
            Write-Log "WARNING: Tool gibt Exit-Code $LASTEXITCODE zurueck" "Orange"
        }
    } catch {
        Write-Log "WARNING: Tool test failed: $($_.Exception.Message)" "Orange"
    }
    
    # Tool direkt mit erweiterter Fehlerbehandlung ausfuehren
    try {
        Write-Log "=== EXTENDED TOOL DIAGNOSTICS ===" "Blue"
        
        # Tool-Befehl zusammenstellen und protokollieren
        $ToolArgs = @("-c", $SourceFolder, "-s", "install.cmd", "-o", $OutputFolder)
        Write-Log "Executing: $IntuneTool $($ToolArgs -join ' ')" "Blue"
        
        # Process-Objekt fuer bessere Kontrolle erstellen
        $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
        $ProcessInfo.FileName = $IntuneTool
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
        Write-Log "Starting IntuneWinAppUtil.exe..." "Blue"
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
        
        Write-Log "=== TOOL OUTPUT ANALYSIS ===" "Blue"
        Write-Log "Exit Code: $ExitCode" "Blue"
        
        if ($OutputText) {
            Write-Log "Standard Output:" "Blue"
            $OutputText -split "`n" | ForEach-Object {
                if ($_.Trim()) { Write-Log "  $($_.Trim())" "Gray" }
            }
        } else {
            Write-Log "No standard output received" "Orange"
        }
        
        if ($ErrorText) {
            Write-Log "Error Output:" "Red"
            $ErrorText -split "`n" | ForEach-Object {
                if ($_.Trim()) { Write-Log "  $($_.Trim())" "Red" }
            }
        } else {
            Write-Log "No error output received" "Green"
        }
        
        Write-Log "=========================" "Blue"
        
        # Erfolg basierend auf Exit-Code pruefen
        if ($ExitCode -ne 0) {
            Write-Log "Tool exited with error code: $ExitCode" "Red"
            
            # Haeufige Exit-Codes interpretieren
            $errorMsg = switch ($ExitCode) {
                1 { "Allgemeiner Anwendungsfehler - pruefen Sie Berechtigungen und parameters" }
                2 { "Ungueltige parameters oder Dateien not found" }
                3 { "Zugriffsberechtigung verweigert - fuehren Sie als Administrator aus" }
                5 { "Ausgabeordner nicht beschreibbar" }
                87 { "Ungueltige parameters-Syntax" }
                -1 { "Schwerwiegender interner Fehler" }
                default { "Unbekannter Exit Code: $ExitCode" }
            }
            Write-Log "Error details: $errorMsg" "Red"
        }
        
    } catch {
        Write-Log "CRITICAL ERROR during tool execution: $($_.Exception.Message)" "Red"
        Write-Log "Exception type: $($_.Exception.GetType().Name)" "Red"
        
        # Hide progress bar
        $elements.progressBar.Visibility = "Collapsed"
        $elements.progressBar.IsIndeterminate = $false
        return
    }
    
    # Hide progress bar
    $elements.progressBar.Visibility = "Collapsed"
    $elements.progressBar.IsIndeterminate = $false
    
    # Pruefen ob .intunewin successful created wurde
    Write-Log "=== SUCCESS VERIFICATION ===" "Blue"
    Write-Log "Checking output folder: $OutputFolder" "Blue"
    Start-Sleep -Seconds 2  # Warten fuer Dateisystem-Sync
    
    $IntunewinFile = Get-ChildItem -Path $OutputFolder -Filter "*.intunewin" -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if ($IntunewinFile) {
        Write-Log ".intunewin Paket successful created!" "Green"
        Write-Log "File: $($IntunewinFile.Name)" "Green"
        Write-Log "Size: $([math]::Round($IntunewinFile.Length / 1KB, 2)) KB" "Green"
        Write-Log "Path: $($IntunewinFile.FullName)" "Green"
    } else {
        Write-Log "ERROR: No .intunewin file found in output folder!" "Red"
        
        # Erweiterte Diagnose
        Write-Log "=== DETAILED FOLDER DIAGNOSTICS ===" "Orange"
        Write-Log "Output folder contents ($OutputFolder):" "Orange"
        
        try {
            $OutputContents = Get-ChildItem -Path $OutputFolder -Force -ErrorAction SilentlyContinue
            if ($OutputContents) {
                foreach ($Item in $OutputContents) {
                    $Size = if ($Item.PSIsContainer) { "[Ordner]" } else { "$([math]::Round($Item.Length / 1KB, 2)) KB" }
                    $Type = if ($Item.PSIsContainer) { "[Ordner]" } else { "[Datei]" }
                    Write-Log "  $Type $($Item.Name) ($Size)" "Orange"
                }
            } else {
                Write-Log "  Folder is completely empty!" "Red"
            }
        } catch {
            Write-Log "  Fehler reading the Ausgabe-folder: $($_.Exception.Message)" "Red"
        }
        
        Write-Log "Source folder contents ($SourceFolder):" "Orange"
        try {
            $SourceContents = Get-ChildItem -Path $SourceFolder -Force -ErrorAction SilentlyContinue
            foreach ($Item in $SourceContents) {
                $Size = if ($Item.PSIsContainer) { "[Ordner]" } else { "$([math]::Round($Item.Length / 1KB, 2)) KB" }
                $Type = if ($Item.PSIsContainer) { "[Ordner]" } else { "[Datei]" }
                Write-Log "  $Type $($Item.Name) ($Size)" "Orange"
            }
        } catch {
            Write-Log "  Fehler reading the Quell-folder: $($_.Exception.Message)" "Red"
        }
        
        Write-Log "====================================" "Orange"
        
        # Umfassende Troubleshooting-Tipps
        Write-Log "TROUBLESHOOTING-ANLEITUNG:" "Yellow"
        Write-Log "1. parameters PRUEFEN:" "Yellow"
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
        UninstallMethod = if ($UninstallInfo.Found) { "Registry" } else { "EXE parameterss" }
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
    Write-Log "Rueckgabecodes: 0 (Erfolg)$(if ($ExitCode -eq 3010) { ', 3010 (Neustart erforderlich)' } else { '' })"
    Write-Log "====================================="
    
    # Frage, ob der Ausgabeordner geoeffnet werden soll
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Paket successful created. Moechten Sie den Ausgabeordner oeffnen?",
        "Paket created",
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




