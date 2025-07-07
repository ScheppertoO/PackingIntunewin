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
    
    Write-Log "IntuneWinAppUtil.exe not found, downloading from alternative sources..." "Orange"
    
    try {
        # Show progress bar
        $elements.progressBar.Visibility = "Visible"
        $elements.progressBar.IsIndeterminate = $true
        
        # Enable TLS 1.2 (required for modern downloads)
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Try different download methods
        $Downloaded = $false
        
        # Method 1: Alternative mirror sites and archive sources
        Write-Log "Trying alternative download sources..."
        $AlternativeUrls = @(
            "https://archive.org/download/IntuneWinAppUtil/IntuneWinAppUtil.exe",
            "https://github.com/MSEndpointMgr/IntuneWin32App/raw/master/Tools/IntuneWinAppUtil.exe",
            "https://download.microsoft.com/download/8/b/e/8be61b72-ae5a-4cd9-8b01-6f6c8b8e4f8e/IntuneWinAppUtil.exe",
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
                
                if ((Test-Path $IntuneTool) -and ((Get-Item $IntuneTool).Length -gt 100000)) {
                    Write-Log "Download successful from: $Url" "Green"
                    $Downloaded = $true
                    break
                } else {
                    if (Test-Path $IntuneTool) { Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue }
                }
                
            } catch {
                Write-Log "URL failed: $($_.Exception.Message)" "Red"
                if (Test-Path $IntuneTool) { Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue }
            }
        }
        
        # Method 2: Fallback to GitHub source and local compilation (if .NET available)
        if (-not $Downloaded) {
            Write-Log "All direct downloads failed, trying source code download..." "Orange"
            
            try {
                $SourceUrl = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/archive/refs/tags/v1.8.6.zip"
                $TempZip = Join-Path $env:TEMP "IntuneWinAppUtil_Source_$(Get-Random).zip"
                $TempExtract = Join-Path $env:TEMP "IntuneWinAppUtil_Source_Extract_$(Get-Random)"
                
                $webClient = New-Object System.Net.WebClient
                $webClient.Headers.Add("User-Agent", "PowerShell-IntuneWinAppUtil-Downloader")
                $webClient.Proxy = [System.Net.WebRequest]::DefaultWebProxy
                $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                
                Write-Log "Downloading source code..."
                $webClient.DownloadFile($SourceUrl, $TempZip)
                
                if ((Test-Path $TempZip) -and ((Get-Item $TempZip).Length -gt 10000)) {
                    Write-Log "Source code downloaded successfully" "Green"
                    
                    # Extract and look for precompiled binaries
                    Expand-Archive -Path $TempZip -DestinationPath $TempExtract -Force
                    
                    # Search for already compiled EXE files in source
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
        
        # Check success
        if ($Downloaded -and (Test-Path $IntuneTool)) {
            $FileInfo = Get-Item $IntuneTool
            if ($FileInfo.Length -gt 100000) { # At least 100KB
                Write-Log "Download successful! File size: $([math]::Round($FileInfo.Length / 1MB, 2)) MB" "Green"
                
                # Check version if possible
                try {
                    $VersionInfo = & $IntuneTool -v 2>&1
                    if ($VersionInfo -match "(\d+\.\d+\.\d+)") {
                        Write-Log "Tool version: $($Matches[1])" "Green"
                    }
                } catch {
                    # Version check failed, but that's ok
                }
                
                return $true
            } else {
                Write-Log "Downloaded file too small (possibly corrupt)" "Red"
                Remove-Item $IntuneTool -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Fallback: Detailed manual instructions
        Write-Log "All automatic download methods failed!" "Red"
        Write-Log "" 
        Write-Log "=== MANUAL INSTALLATION ===" "Orange"
        Write-Log "The tool is unfortunately no longer directly available from GitHub." "Orange"
        Write-Log "" 
        Write-Log "OPTION 1 - Microsoft Download Center:" "Yellow"
        Write-Log "1. Visit: https://aka.ms/win32contentpreptool" "Yellow"
        Write-Log "2. Or search for 'Microsoft Win32 Content Prep Tool'" "Yellow"
        Write-Log "" 
        Write-Log "OPTION 2 - Alternative sources:" "Yellow"
        Write-Log "1. Search the internet for 'IntuneWinAppUtil.exe download'" "Yellow"
        Write-Log "2. Check PowerShell Gallery or Chocolatey" "Yellow"
        Write-Log "" 
        Write-Log "OPTION 3 - From existing Intune Admin Center:" "Yellow"
        Write-Log "1. Log in to https://endpoint.microsoft.com" "Yellow"
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
            "• Go to https://endpoint.microsoft.com`n" +
            "• Apps > Windows > Add > Win32 app`n" +
            "• Download the tool from there`n`n" +
            "Save IntuneWinAppUtil.exe to:`n$ToolsPath",
            "Download Error - Manual Installation Required",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return $false
        
    } catch {
        Write-Log "Critical error during download: $($_.Exception.Message)" "Red"
        [System.Windows.Forms.MessageBox]::Show(
            "Critical error during download!`n`nError: $($_.Exception.Message)`n`n" +
            "Please download IntuneWinAppUtil.exe manually from:`n" +
            "https://aka.ms/win32contentpreptool`n`n" +
            "And save it to: $ToolsPath",
            "Critical Download Error",
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
    Write-Log "Tool command: $IntuneTool -c `"$SourceFolder`" -s `"install.cmd`" -o `"$OutputFolder`"" "Gray"
    
    # Detailed parameter validation
    Write-Log "Validating parameters..." "Blue"
    Write-Log "   Source folder: $SourceFolder (Exists: $(Test-Path $SourceFolder))" "Gray"
    Write-Log "   Setup file: install.cmd (Exists: $(Test-Path "$SourceFolder\install.cmd"))" "Gray"
    Write-Log "   Output folder: $OutputFolder (Exists: $(Test-Path $OutputFolder))" "Gray"
    Write-Log "   IntuneWinAppUtil: $IntuneTool (Exists: $(Test-Path $IntuneTool))" "Gray"
    
    # Test tool functionality
    try {
        Write-Log "Testing tool version..." "Blue"
        $versionResult = & $IntuneTool -h 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Tool is functional" "Green"
        } else {
            Write-Log "WARNING: Tool returns exit code $LASTEXITCODE" "Orange"
        }
    } catch {
        Write-Log "WARNING: Tool test failed: $($_.Exception.Message)" "Orange"
    }
    
    # Execute tool directly with enhanced error handling
    try {
        Write-Log "=== EXTENDED TOOL DIAGNOSTICS ===" "Blue"
        
        # Compile and log tool command
        $ToolArgs = @("-c", $SourceFolder, "-s", "install.cmd", "-o", $OutputFolder)
        Write-Log "Executing: $IntuneTool $($ToolArgs -join ' ')" "Blue"
        
        # Create process object for better control
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
        
        # Output handlers
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
        
        # Start process
        Write-Log "Starting IntuneWinAppUtil.exe..." "Blue"
        $Process.Start()
        $Process.BeginOutputReadLine()
        $Process.BeginErrorReadLine()
        
        # 3 minute timeout for larger apps
        $TimeoutMs = 180000
        if (-not $Process.WaitForExit($TimeoutMs)) {
            Write-Log "TIMEOUT: Tool not responding after 3 minutes - terminating process" "Red"
            $Process.Kill()
            $Process.WaitForExit()
            throw "Tool timeout after 3 minutes"
        }
        
        $ExitCode = $Process.ExitCode
        $Process.Close()
        
        # Log output
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
        
        # Check success based on exit code
        if ($ExitCode -ne 0) {
            Write-Log "[ERROR] Tool exited with error code: $ExitCode" "Red"
            
            # Interpret common exit codes
            $errorMsg = switch ($ExitCode) {
                1 { "General application error - check permissions and parameters" }
                2 { "Invalid parameters or files not found" }
                3 { "Access denied - run as administrator" }
                5 { "Output folder not writable" }
                87 { "Invalid parameter syntax" }
                -1 { "Severe internal error" }
                default { "Unknown exit code: $ExitCode" }
            }
            Write-Log "Error details: $errorMsg" "Red"
        }
        
    } catch {
        Write-Log "[CRITICAL ERROR] during tool execution: $($_.Exception.Message)" "Red"
        Write-Log "Exception type: $($_.Exception.GetType().Name)" "Red"
        
        # Hide progress bar
        $elements.progressBar.Visibility = "Collapsed"
        $elements.progressBar.IsIndeterminate = $false
        return
    }
    
    # Hide progress bar
    $elements.progressBar.Visibility = "Collapsed"
    $elements.progressBar.IsIndeterminate = $false
    
    # Check if .intunewin was successfully created
    Write-Log "=== SUCCESS VERIFICATION ===" "Blue"
    Write-Log "Checking output folder: $OutputFolder" "Blue"
    Start-Sleep -Seconds 2  # Wait for filesystem sync
    
    $IntunewinFile = Get-ChildItem -Path $OutputFolder -Filter "*.intunewin" -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if ($IntunewinFile) {
        Write-Log "[SUCCESS] .intunewin package successfully created!" "Green"
        Write-Log "File: $($IntunewinFile.Name)" "Green"
        Write-Log "Size: $([math]::Round($IntunewinFile.Length / 1KB, 2)) KB" "Green"
    } else {
        Write-Log "[ERROR] No .intunewin file found in output folder!" "Red"
        
        # Enhanced diagnostics
        Write-Log "=== DETAILED FOLDER DIAGNOSTICS ===" "Orange"
        Write-Log "Output folder contents ($OutputFolder):" "Orange"
        
        try {
            $OutputContents = Get-ChildItem -Path $OutputFolder -Force -ErrorAction SilentlyContinue
            if ($OutputContents) {
                foreach ($Item in $OutputContents) {
                    $Size = if ($Item.PSIsContainer) { "[Folder]" } else { "$([math]::Round($Item.Length / 1KB, 2)) KB" }
                    $Type = if ($Item.PSIsContainer) { "[DIR]" } else { "[FILE]" }
                    Write-Log "  $Type $($Item.Name) ($Size)" "Orange"
                }
            } else {
                Write-Log "  [ERROR] Folder is completely empty!" "Red"
            }
        } catch {
            Write-Log "  [ERROR] Error reading output folder: $($_.Exception.Message)" "Red"
        }
        
        Write-Log "Source folder contents ($SourceFolder):" "Orange"
        try {
            $SourceContents = Get-ChildItem -Path $SourceFolder -Force -ErrorAction SilentlyContinue
            foreach ($Item in $SourceContents) {
                $Size = if ($Item.PSIsContainer) { "[Folder]" } else { "$([math]::Round($Item.Length / 1KB, 2)) KB" }
                $Type = if ($Item.PSIsContainer) { "[DIR]" } else { "[FILE]" }
                Write-Log "  $Type $($Item.Name) ($Size)" "Orange"
            }
        } catch {
            Write-Log "  [ERROR] Error reading source folder: $($_.Exception.Message)" "Red"
        }
        
        Write-Log "====================================" "Orange"
        
        # Comprehensive troubleshooting guide
        Write-Log "[TROUBLESHOOTING GUIDE]" "Yellow"
        Write-Log "1. CHECK PARAMETERS:" "Yellow"
        Write-Log "   • install.cmd exists and is valid" "Yellow"
        Write-Log "   • EXE file is present in source folder" "Yellow"
        Write-Log "   • Source and output folders are different" "Yellow"
        Write-Log "" 
        Write-Log "2. CHECK PERMISSIONS:" "Yellow"
        Write-Log "   • Run as administrator" "Yellow"
        Write-Log "   • Write permission in output folder" "Yellow"
        Write-Log "   • No file locking by other programs" "Yellow"
        Write-Log "" 
        Write-Log "3. ANTIVIRUS / SECURITY:" "Yellow"
        Write-Log "   • Add Windows Defender exclusion" "Yellow"
        Write-Log "   • Temporarily exclude folders from antivirus" "Yellow"
        Write-Log "   • Check UAC (User Account Control)" "Yellow"
        Write-Log "" 
        Write-Log "4. MANUAL TEST:" "Yellow"
        Write-Log "   Try this command in command prompt:" "Yellow"
        Write-Log "   cd /d `"$ScriptPath`"" "Yellow"
        Write-Log "   `"$IntuneTool`" -c `"$SourceFolder`" -s `"install.cmd`" -o `"$OutputFolder`"" "Yellow"
        Write-Log "" 
        Write-Log "5. ALTERNATIVE SOLUTIONS:" "Yellow"
        Write-Log "   • Try a different app folder" "Yellow"
        Write-Log "   • Use shorter path names (no special characters)" "Yellow"
        Write-Log "   • Copy files to local folder (not network)" "Yellow"
        Write-Log "   • Restart computer if necessary" "Yellow"
        
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
