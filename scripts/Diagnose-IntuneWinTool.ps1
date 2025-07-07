# IntuneWin Packaging Tool - Diagnostic Script
# This script helps diagnose common issues with .intunewin package creation

param(
    [string]$AppFolderName = "test"
)

Write-Host "=== INTUNE WIN TOOL DIAGNOSTICS ===" -ForegroundColor Cyan
Write-Host "App folder to test: $AppFolderName" -ForegroundColor Yellow
Write-Host ""

# Get script location (main directory is one level up from scripts folder)
$ScriptPath = Split-Path $PSScriptRoot -Parent
$BaseInputPath = Join-Path $ScriptPath "apps"
$BaseOutputPath = Join-Path $ScriptPath "IntunewinApps"
$ToolsPath = Join-Path $ScriptPath "IntunewinApps\tools"
$IntuneTool = Join-Path $ToolsPath "IntuneWinAppUtil.exe"

Write-Host "1. CHECKING FOLDER STRUCTURE..." -ForegroundColor Green

$RequiredPaths = @{
    "Script Directory" = $ScriptPath
    "Apps Folder" = $BaseInputPath
    "Output Folder" = $BaseOutputPath
    "Tools Folder" = $ToolsPath
    "IntuneWinAppUtil" = $IntuneTool
}

foreach ($PathName in $RequiredPaths.Keys) {
    $Path = $RequiredPaths[$PathName]
    $Exists = Test-Path $Path
    $Status = if ($Exists) { "✅ EXISTS" } else { "❌ MISSING" }
    $Color = if ($Exists) { "Green" } else { "Red" }
    
    Write-Host "   $PathName`: $Status" -ForegroundColor $Color
    Write-Host "     Path: $Path" -ForegroundColor Gray
}

Write-Host ""
Write-Host "2. CHECKING APP FOLDER..." -ForegroundColor Green

$AppSourceFolder = Join-Path $BaseInputPath $AppFolderName
$AppOutputFolder = Join-Path $BaseOutputPath $AppFolderName

if (Test-Path $AppSourceFolder) {
    Write-Host "   App Source Folder: ✅ EXISTS" -ForegroundColor Green
    Write-Host "     Path: $AppSourceFolder" -ForegroundColor Gray
    
    $AppContents = Get-ChildItem -Path $AppSourceFolder -Force
    Write-Host "   Contents:" -ForegroundColor Yellow
    
    foreach ($Item in $AppContents) {
        $Size = if ($Item.PSIsContainer) { "[Folder]" } else { "$([math]::Round($Item.Length / 1KB, 2)) KB" }
        $Type = if ($Item.PSIsContainer) { "📁" } else { "📄" }
        Write-Host "     $Type $($Item.Name) ($Size)" -ForegroundColor Gray
    }
    
    # Check for EXE files
    $ExeFiles = Get-ChildItem -Path $AppSourceFolder -Filter "*.exe"
    if ($ExeFiles.Count -gt 0) {
        Write-Host "   EXE Files Found: ✅ $($ExeFiles.Count)" -ForegroundColor Green
        foreach ($exe in $ExeFiles) {
            Write-Host "     - $($exe.Name) ($([math]::Round($exe.Length / 1KB, 2)) KB)" -ForegroundColor Gray
        }
    } else {
        Write-Host "   EXE Files Found: ❌ NONE" -ForegroundColor Red
        Write-Host "     ERROR: No .exe files found in app folder!" -ForegroundColor Red
    }
    
} else {
    Write-Host "   App Source Folder: ❌ MISSING" -ForegroundColor Red
    Write-Host "     Path: $AppSourceFolder" -ForegroundColor Gray
    Write-Host "     ERROR: App folder does not exist!" -ForegroundColor Red
}

Write-Host ""
Write-Host "3. CHECKING INTUNE WIN APP UTIL..." -ForegroundColor Green

if (Test-Path $IntuneTool) {
    $ToolInfo = Get-Item $IntuneTool
    Write-Host "   Tool File: ✅ EXISTS" -ForegroundColor Green
    Write-Host "     Path: $IntuneTool" -ForegroundColor Gray
    Write-Host "     Size: $([math]::Round($ToolInfo.Length / 1MB, 2)) MB" -ForegroundColor Gray
    Write-Host "     Created: $($ToolInfo.CreationTime)" -ForegroundColor Gray
    
    # Test tool execution
    try {
        Write-Host "   Testing tool execution..." -ForegroundColor Yellow
        $TestResult = & $IntuneTool -h 2>&1
        $ExitCode = $LASTEXITCODE
        
        if ($ExitCode -eq 0) {
            Write-Host "   Tool Execution: ✅ SUCCESS (Exit Code: $ExitCode)" -ForegroundColor Green
        } else {
            Write-Host "   Tool Execution: ⚠️  WARNING (Exit Code: $ExitCode)" -ForegroundColor Yellow
        }
        
        # Show first few lines of help output
        if ($TestResult) {
            $HelpLines = ($TestResult | Out-String).Split("`n") | Select-Object -First 3
            foreach ($Line in $HelpLines) {
                if ($Line.Trim()) {
                    Write-Host "     $($Line.Trim())" -ForegroundColor Gray
                }
            }
        }
        
    } catch {
        Write-Host "   Tool Execution: ❌ FAILED" -ForegroundColor Red
        Write-Host "     Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
} else {
    Write-Host "   Tool File: ❌ MISSING" -ForegroundColor Red
    Write-Host "     Path: $IntuneTool" -ForegroundColor Gray
    Write-Host "     ERROR: IntuneWinAppUtil.exe not found!" -ForegroundColor Red
}

Write-Host ""
Write-Host "4. CHECKING PERMISSIONS..." -ForegroundColor Green

# Check if running as admin
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
$AdminStatus = if ($IsAdmin) { "✅ YES" } else { "❌ NO" }
$AdminColor = if ($IsAdmin) { "Green" } else { "Red" }
Write-Host "   Running as Administrator: $AdminStatus" -ForegroundColor $AdminColor

# Check write permissions
try {
    $TestFile = Join-Path $BaseOutputPath "test_write_permission.tmp"
    "test" | Out-File -FilePath $TestFile -ErrorAction Stop
    Remove-Item $TestFile -Force -ErrorAction SilentlyContinue
    Write-Host "   Write Permission (Output): ✅ YES" -ForegroundColor Green
} catch {
    Write-Host "   Write Permission (Output): ❌ NO" -ForegroundColor Red
    Write-Host "     Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "5. SIMULATING PACKAGE CREATION..." -ForegroundColor Green

if ((Test-Path $AppSourceFolder) -and (Test-Path $IntuneTool) -and $ExeFiles.Count -gt 0) {
    Write-Host "   Prerequisites: ✅ MET" -ForegroundColor Green
    
    # Create install.cmd for testing
    $TestInstallCmd = @"
@echo off
echo Installing $AppFolderName...
$($ExeFiles[0].Name) /silent
if %errorlevel% neq 0 (
    echo Installation failed with exit code %errorlevel%
    exit /b %errorlevel%
)
echo Installation completed successfully
exit /b 0
"@
    
    $InstallCmdPath = Join-Path $AppSourceFolder "install.cmd"
    try {
        Set-Content -Path $InstallCmdPath -Value $TestInstallCmd -Encoding ASCII
        Write-Host "   Test install.cmd: ✅ CREATED" -ForegroundColor Green
    } catch {
        Write-Host "   Test install.cmd: ❌ FAILED" -ForegroundColor Red
        Write-Host "     Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Create output folder
    New-Item -ItemType Directory -Force -Path $AppOutputFolder | Out-Null
    
    # Test the actual tool command
    Write-Host "   Running IntuneWinAppUtil..." -ForegroundColor Yellow
    Write-Host "   Command: $IntuneTool -c `"$AppSourceFolder`" -s `"install.cmd`" -o `"$AppOutputFolder`"" -ForegroundColor Gray
    
    try {
        $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
        $ProcessInfo.FileName = $IntuneTool
        $ProcessInfo.Arguments = "-c `"$AppSourceFolder`" -s `"install.cmd`" -o `"$AppOutputFolder`""
        $ProcessInfo.RedirectStandardOutput = $true
        $ProcessInfo.RedirectStandardError = $true
        $ProcessInfo.UseShellExecute = $false
        $ProcessInfo.CreateNoWindow = $true
        
        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo = $ProcessInfo
        $Process.Start()
        
        $Timeout = 60000  # 1 minute timeout
        if (-not $Process.WaitForExit($Timeout)) {
            $Process.Kill()
            Write-Host "   Tool Execution: ❌ TIMEOUT (after 1 minute)" -ForegroundColor Red
        } else {
            $ExitCode = $Process.ExitCode
            $StdOut = $Process.StandardOutput.ReadToEnd()
            $StdErr = $Process.StandardError.ReadToEnd()
            
            if ($ExitCode -eq 0) {
                Write-Host "   Tool Execution: ✅ SUCCESS (Exit Code: $ExitCode)" -ForegroundColor Green
            } else {
                Write-Host "   Tool Execution: ❌ FAILED (Exit Code: $ExitCode)" -ForegroundColor Red
                
                $ErrorMsg = switch ($ExitCode) {
                    1 { "General application error" }
                    2 { "Invalid parameters or files not found" }
                    3 { "Access denied" }
                    5 { "Output folder not writable" }
                    87 { "Invalid parameter syntax" }
                    default { "Unknown error" }
                }
                Write-Host "     Error meaning: $ErrorMsg" -ForegroundColor Red
            }
            
            if ($StdOut.Trim()) {
                Write-Host "   Standard Output:" -ForegroundColor Yellow
                $StdOut.Split("`n") | ForEach-Object {
                    if ($_.Trim()) { Write-Host "     $($_.Trim())" -ForegroundColor Gray }
                }
            }
            
            if ($StdErr.Trim()) {
                Write-Host "   Error Output:" -ForegroundColor Red
                $StdErr.Split("`n") | ForEach-Object {
                    if ($_.Trim()) { Write-Host "     $($_.Trim())" -ForegroundColor Red }
                }
            }
        }
        
        $Process.Close()
        
    } catch {
        Write-Host "   Tool Execution: ❌ EXCEPTION" -ForegroundColor Red
        Write-Host "     Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Check if .intunewin was created
    Start-Sleep -Seconds 2
    $IntunewinFiles = Get-ChildItem -Path $AppOutputFolder -Filter "*.intunewin" -ErrorAction SilentlyContinue
    
    if ($IntunewinFiles.Count -gt 0) {
        Write-Host "   .intunewin Creation: ✅ SUCCESS" -ForegroundColor Green
        foreach ($file in $IntunewinFiles) {
            Write-Host "     - $($file.Name) ($([math]::Round($file.Length / 1KB, 2)) KB)" -ForegroundColor Gray
        }
    } else {
        Write-Host "   .intunewin Creation: ❌ FAILED" -ForegroundColor Red
        Write-Host "     No .intunewin files found in output folder" -ForegroundColor Red
        
        # List what IS in the output folder
        $OutputContents = Get-ChildItem -Path $AppOutputFolder -Force -ErrorAction SilentlyContinue
        if ($OutputContents) {
            Write-Host "   Output folder contains:" -ForegroundColor Yellow
            foreach ($item in $OutputContents) {
                $Size = if ($item.PSIsContainer) { "[Folder]" } else { "$([math]::Round($item.Length / 1KB, 2)) KB" }
                Write-Host "     - $($item.Name) ($Size)" -ForegroundColor Gray
            }
        } else {
            Write-Host "     Output folder is empty!" -ForegroundColor Red
        }
    }
    
} else {
    Write-Host "   Prerequisites: ❌ NOT MET" -ForegroundColor Red
    Write-Host "     Cannot simulate package creation due to missing prerequisites" -ForegroundColor Red
}

Write-Host ""
Write-Host "6. RECOMMENDATIONS..." -ForegroundColor Green

$Issues = @()
if (-not (Test-Path $IntuneTool)) { $Issues += "Download IntuneWinAppUtil.exe to tools folder" }
if (-not (Test-Path $AppSourceFolder)) { $Issues += "Create the app folder '$AppFolderName' in apps directory" }
if ((Test-Path $AppSourceFolder) -and (Get-ChildItem -Path $AppSourceFolder -Filter "*.exe").Count -eq 0) { 
    $Issues += "Add .exe file(s) to the app folder" 
}
if (-not $IsAdmin) { $Issues += "Run PowerShell as Administrator for better permissions" }

if ($Issues.Count -eq 0) {
    Write-Host "   No major issues detected! ✅" -ForegroundColor Green
    Write-Host "   If packaging still fails, check antivirus software and Windows Defender." -ForegroundColor Yellow
} else {
    Write-Host "   Issues to resolve:" -ForegroundColor Yellow
    foreach ($Issue in $Issues) {
        Write-Host "   - $Issue" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== DIAGNOSTIC COMPLETE ===" -ForegroundColor Cyan
Write-Host "Save this output and share it for further troubleshooting if needed." -ForegroundColor Yellow
