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

# Load XAML and convert to WPF object
$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Get GUI elements
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
                Write-Log "WARNING: Multiple EXE files found in $selectedApp. First one will be used: $($exeFiles[0].Name)" "Orange"
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
        Write-Log "Apps folder not found. Please initialize the folder structure." "Red"
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
    
    # Refresh app list
    Refresh-AppList
}

function Test-IntuneWinAppUtilGUI {
    Write-Log "Checking IntuneWinAppUtil.exe..." "Blue"
    
    # Create tools folder if not present
    if (-not (Test-Path $ToolsPath)) {
        Write-Log "Creating tools folder: $ToolsPath"
        New-Item -ItemType Directory -Force -Path $ToolsPath | Out-Null
    }
    
    # Check if IntuneWinAppUtil.exe is present
    if (Test-Path $IntuneTool) {
        Write-Log "IntuneWinAppUtil.exe found: $IntuneTool" "Green"
        return $true
    }
    
    Write-Log "IntuneWinAppUtil.exe not found, downloading from GitHub..." "Orange"
    
    try {
        # Show progress bar
        $elements.progressBar.Visibility = "Visible"
        $elements.progressBar.IsIndeterminate = $true
        
        # Enable TLS 1.2 (required for modern GitHub downloads)
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Try different download methods
        $Downloaded = $false
        
        # Method 1: GitHub Releases API with robust error handling
        Write-Log "Looking for the latest version..."
        try {
            $ApiUrl = "https://api.github.com/repos/microsoft/Microsoft-Win32-Content-Prep-Tool/releases/latest"
            
            # Configure HTTP client with timeout
            $webRequest = [System.Net.HttpWebRequest]::Create($ApiUrl)
            $webRequest.Timeout = 30000 # 30 seconds
            $webRequest.UserAgent = "PowerShell-IntuneWinAppUtil-Downloader"
            
            $response = $webRequest.GetResponse()
            $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
            $jsonContent = $reader.ReadToEnd()
            $reader.Close()
            $response.Close()
            
            $Release = $jsonContent | ConvertFrom-Json
            
            # Search for ZIP files in assets
            $ZipAsset = $Release.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
            
            if ($ZipAsset) {
                Write-Log "Found: $($ZipAsset.name) (Version: $($Release.tag_name))" "Green"
                Write-Log "Download URL: $($ZipAsset.browser_download_url)" 
                
                # Temporary directory for download
                $TempZip = Join-Path $env:TEMP "IntuneWinAppUtil_$(Get-Random).zip"
                $TempExtract = Join-Path $env:TEMP "IntuneWinAppUtil_Extract_$(Get-Random)"
                
                # Download ZIP file with improved HTTP client
                $webClient = New-Object System.Net.WebClient
                $webClient.Headers.Add("User-Agent", "PowerShell-IntuneWinAppUtil-Downloader")
                $webClient.Encoding = [System.Text.Encoding]::UTF8
                
                # Use proxy settings if available
                $webClient.Proxy = [System.Net.WebRequest]::DefaultWebProxy
                $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                
                $webClient.DownloadFile($ZipAsset.browser_download_url, $TempZip)
                
                # Check if ZIP was downloaded correctly
                if ((Test-Path $TempZip) -and ((Get-Item $TempZip).Length -gt 0)) {
                    Write-Log "ZIP file downloaded successfully" "Green"
                    
                    # Extract ZIP
                    if (Test-Path $TempExtract) {
                        Remove-Item $TempExtract -Recurse -Force
                    }
                    Expand-Archive -Path $TempZip -DestinationPath $TempExtract -Force
                    
                    # Search for IntuneWinAppUtil.exe
                    $ExeFile = Get-ChildItem -Path $TempExtract -Filter "IntuneWinAppUtil.exe" -Recurse | Select-Object -First 1
                    
                    if ($ExeFile) {
                        Copy-Item $ExeFile.FullName $IntuneTool -Force
                        Write-Log "IntuneWinAppUtil.exe successfully extracted!" "Green"
                        $Downloaded = $true
                    } else {
                        Write-Log "IntuneWinAppUtil.exe not found in ZIP" "Red"
                    }
                } else {
                    Write-Log "ZIP download failed or file empty" "Red"
                }
                
                # Cleanup
                if (Test-Path $TempZip) { Remove-Item $TempZip -Force -ErrorAction SilentlyContinue }
                if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force -ErrorAction SilentlyContinue }
            } else {
                Write-Log "No ZIP file found in release" "Orange"
            }
        } catch {
            Write-Log "GitHub API Error: $($_.Exception.Message)" "Red"
        }
        
        # Method 2: Current release URLs (improved)
        if (-not $Downloaded) {
            Write-Log "Trying current release URLs..." "Orange"
            
            # Current URLs based on GitHub release structure
            $ReleaseUrls = @(
                "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/releases/download/v1.8.7/Microsoft.Win32.ContentPrepTool.zip",
                "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/releases/download/v1.8.6/Microsoft.Win32.ContentPrepTool.zip",
                "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/archive/refs/heads/master.zip"
            )
            
            foreach ($Url in $ReleaseUrls) {
                try {
                    Write-Log "  Trying: $Url" 
                    
                    $TempZip = Join-Path $env:TEMP "IntuneWinAppUtil_$(Get-Random).zip"
                    $TempExtract = Join-Path $env:TEMP "IntuneWinAppUtil_Extract_$(Get-Random)"
                    
                    $webClient = New-Object System.Net.WebClient
                    $webClient.Headers.Add("User-Agent", "PowerShell-IntuneWinAppUtil-Downloader")
                    $webClient.Proxy = [System.Net.WebRequest]::DefaultWebProxy
                    $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                    
                    $webClient.DownloadFile($Url, $TempZip)
                    
                    if ((Test-Path $TempZip) -and ((Get-Item $TempZip).Length -gt 1000)) {
                        # Extract ZIP
                        Expand-Archive -Path $TempZip -DestinationPath $TempExtract -Force
                        
                        # Search for IntuneWinAppUtil.exe recursively
                        $ExeFile = Get-ChildItem -Path $TempExtract -Filter "IntuneWinAppUtil.exe" -Recurse | Select-Object -First 1
                        
                        if ($ExeFile) {
                            Copy-Item $ExeFile.FullName $IntuneTool -Force
                            Write-Log "Download successful from: $Url" "Green"
                            $Downloaded = $true
                            
                            # Cleanup
                            if (Test-Path $TempZip) { Remove-Item $TempZip -Force -ErrorAction SilentlyContinue }
                            if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force -ErrorAction SilentlyContinue }
                            break
                        }
                    }
                    
                    # Cleanup on failure
                    if (Test-Path $TempZip) { Remove-Item $TempZip -Force -ErrorAction SilentlyContinue }
                    if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force -ErrorAction SilentlyContinue }
                    
                } catch {
                    Write-Log "URL failed: $($_.Exception.Message)" "Red"
                }
            }
        }
        
        # Check success
        if ($Downloaded -and (Test-Path $IntuneTool)) {
            $FileInfo = Get-Item $IntuneTool
            if ($FileInfo.Length -gt 100000) { # At least 100KB
                Write-Log "Download successful! File size: $([math]::Round($FileInfo.Length / 1MB, 2)) MB" "Green"
                return $true
            } else {
                Write-Log "Downloaded file too small (possibly corrupt)" "Red"
                Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Fallback: Manual instructions
        Write-Log "All automatic download methods failed!" "Red"
        Write-Log "Manual instructions:" "Orange"
        Write-Log "1. Visit: https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/releases" "Orange"
        Write-Log "2. Download the latest version" "Orange"
        Write-Log "3. Extract IntuneWinAppUtil.exe to: $ToolsPath" "Orange"
        
        [System.Windows.Forms.MessageBox]::Show(
            "Download failed!`n`nManual steps:`n1. Visit: https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/releases`n2. Download the latest version`n3. Extract IntuneWinAppUtil.exe to: $ToolsPath",
            "Download Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return $false
        
    } catch {
        Write-Log "Critical error during download: $($_.Exception.Message)" "Red"
        [System.Windows.Forms.MessageBox]::Show(
            "Critical error during download!`n`nError: $($_.Exception.Message)`n`nPlease download IntuneWinAppUtil.exe manually.",
            "Download Error",
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
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            return $false
        }
        
    } catch {
        Write-Log "Error during download: $($_.Exception.Message)" "Red"
        [System.Windows.Forms.MessageBox]::Show(
            "Error during download! Please manually download IntuneWinAppUtil.exe and place it in the tools folder.",
            "Download Error",
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
    
    Write-Log "Searching for uninstall information for '$AppName'..." "Blue"
    
    # Registry paths for installed programs
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
            # Ignore registry errors
        }
    }
    
    return @{ Found = $false }
}

function Test-ExeUninstallParametersGUI {
    param([string]$ExePath)
    
    Write-Log "Analyzing EXE for uninstall parameters..." "Blue"
    
    # Filename-based heuristics
    Write-Log "Analyzing filename..."
    $FileName = [System.IO.Path]::GetFileNameWithoutExtension($ExePath).ToLower()
    
    # Derive installer type from filename
    if ($FileName -like "*setup*" -or $FileName -like "*install*") {
        Write-Log "Setup/Installer detected from filename" "Green"
        
        if ($FileName -like "*nsis*") {
            return "/S"
        } elseif ($FileName -like "*inno*") {
            return "/SILENT"
        } else {
            return "/uninstall /silent"
        }
    } elseif ($FileName -like "*msi*") {
        Write-Log "MSI-related detected from filename" "Green"
        return "/x /quiet"
    }
    
    # Safe fallback heuristics
    Write-Log "No specific parameters detected, using standard heuristics" "Orange"
    
    # Choose most common standard based on filename
    if ($FileName -like "*setup*") {
        $SelectedParams = "/uninstall /silent"
    }
    elseif ($FileName -like "*install*") {
        $SelectedParams = "/remove /quiet"
    }
    else {
        $SelectedParams = "/uninstall /silent"  # Most common standard
    }
    
    Write-Log "Recommended parameters: $SelectedParams" "Orange"
    return $SelectedParams
}

function Create-IntuneWinAppPackage {
    # Get selected app
    $InputFolder = $elements.cboAppFolder.SelectedItem
    
    if (-not $InputFolder) {
        Write-Log "Please select an app!" "Red"
        return
    }
    
    # Define paths
    $SourceFolder = Join-Path $BaseInputPath $InputFolder
    $OutputFolder = Join-Path $BaseOutputPath $InputFolder
    
    # Check if folder exists
    if (-not (Test-Path $SourceFolder)) {
        Write-Log "App folder '$InputFolder' not found!" "Red"
        return
    }
    
    # Check tool availability
    if (-not (Test-Path $IntuneTool)) {
        $toolResult = Test-IntuneWinAppUtilGUI
        if (-not $toolResult) {
            Write-Log "Required tool missing: IntuneWinAppUtil.exe" "Red"
            return
        }
    }
    
    # Check if an .exe is present
    $ExeFiles = Get-ChildItem -Path $SourceFolder -Filter *.exe
    if ($ExeFiles.Count -eq 0) {
        Write-Log "No .exe found in directory '$SourceFolder'!" "Red"
        return
    }
    
    $ExeName = $ExeFiles[0].Name
    $ExePath = $ExeFiles[0].FullName
    $AppName = [System.IO.Path]::GetFileNameWithoutExtension($ExeName)
    
    Write-Log "Starting packaging for $AppName..." "Blue"
    
    # Check reboot setting
    $RebootRequired = $elements.chkRebootRequired.IsChecked
    if ($RebootRequired) {
        $ExitCode = 3010  # Soft reboot required
        Write-Log "Reboot will be required after installation (Exit Code: 3010)" "Orange"
    } else {
        $ExitCode = 0     # Normal success
        Write-Log "No reboot required (Exit Code: 0)" "Green"
    }
    
    # Determine uninstall information
    $UninstallInfo = Get-UninstallInfoGUI -AppName $AppName -ExePath $ExePath
    
    $UninstallCommand = ""
    if ($UninstallInfo.Found) {
        Write-Log "Registry entry found!" "Green"
        
        if ($UninstallInfo.QuietUninstallString) {
            $UninstallCommand = $UninstallInfo.QuietUninstallString
            Write-Log "Using QuietUninstallString: $UninstallCommand" "Green"
        } else {
            # Try to add /quiet or /silent to UninstallString
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
            Write-Log "Using modified UninstallString: $UninstallCommand" "Orange"
        }
    } else {
        Write-Log "No registry entry found, testing EXE parameters..." "Orange"
        $UninstallParams = Test-ExeUninstallParametersGUI -ExePath $ExePath
        $UninstallCommand = "$ExeName $UninstallParams"
        Write-Log "Using EXE with parameters: $UninstallCommand" "Orange"
    }
    
    # Prepare output folder
    New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null
    
    # Create install.cmd dynamically
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
    
    # Create uninstall.cmd dynamically
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
    
    # Create .intunewin (in background)
    Write-Log "Creating .intunewin package (this may take a moment)..." "Blue"
    
    $job = Start-Job -ScriptBlock {
        param ($IntuneTool, $SourceFolder, $OutputFolder)
        & $IntuneTool -c $SourceFolder -s "install.cmd" -o $OutputFolder
    } -ArgumentList $IntuneTool, $SourceFolder, $OutputFolder
    
    # Wait until job finishes
    while ($job.State -eq "Running") {
        Start-Sleep -Milliseconds 500
    }
    
    # Check job result
    $jobOutput = Receive-Job -Job $job
    Remove-Job -Job $job
    
    # Hide progress bar
    $elements.progressBar.Visibility = "Collapsed"
    $elements.progressBar.IsIndeterminate = $false
    
    # Check if .intunewin was successfully created
    $IntunewinFile = Get-ChildItem -Path $OutputFolder -Filter "*.intunewin" | Select-Object -First 1
    if ($IntunewinFile) {
        Write-Log ".intunewin package successfully created: $($IntunewinFile.Name)" "Green"
    } else {
        Write-Log "Error creating .intunewin package!" "Red"
        Write-Log "Tool output: $jobOutput" "Red"
        return
    }
    
    # Write metadata
    $Meta = @{
        AppName = $AppName
        Installer = $ExeName
        InstallCommand = "install.cmd"
        UninstallCommand = "uninstall.cmd"
        UninstallMethod = if ($UninstallInfo.Found) { "Registry" } else { "EXE Parameters" }
        UninstallString = $UninstallCommand
        ExitCode = $ExitCode
        RebootRequired = ($ExitCode -eq 3010)
        DetectionType = "Registry (configure manually)"
        CreatedOn = (Get-Date).ToString("yyyy-MM-dd HH:mm")
        CreatedBy = $env:USERNAME
        ScriptVersion = "2.0 GUI"
        WorkingDirectory = $ScriptPath
    }
    $Meta | ConvertTo-Json -Depth 3 | Set-Content -Path "$OutputFolder\metadata.json"
    
    Write-Log "Metadata saved in: metadata.json" "Green"
    Write-Log "Packaging completed!" "Green"
    
    # Summary
    Write-Log "`nSummary for Intune:" "Blue"
    Write-Log "====================================="
    Write-Log "App Name: $AppName"
    Write-Log "Install Command: install.cmd"
    Write-Log "Uninstall Command: uninstall.cmd"
    Write-Log "Return Codes: 0 (Success)" + $(if ($ExitCode -eq 3010) { ", 3010 (Reboot required)" } else { "" })
    Write-Log "====================================="
    
    # Ask if output folder should be opened
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Package successfully created. Would you like to open the output folder?",
        "Package Created",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
    
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        Start-Process -FilePath "explorer.exe" -ArgumentList $OutputFolder
    }
}

# Initialize and show GUI
Initialize-GUI
$window.ShowDialog() | Out-Null
