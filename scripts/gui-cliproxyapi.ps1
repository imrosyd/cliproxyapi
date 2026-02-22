<#
.SYNOPSIS
    CLIProxyAPI GUI Control Center with Management Server
.DESCRIPTION
    Starts an HTTP management server that serves the GUI and provides API endpoints
    for controlling the CLIProxyAPI server (start/stop/restart/oauth).
.PARAMETER Port
    Port for the management server (default: 8318)
.PARAMETER NoBrowser
    Don't automatically open browser
.EXAMPLE
    gui-cliproxyapi.ps1
    gui-cliproxyapi.ps1 -Port 9000
    gui-cliproxyapi.ps1 -NoBrowser
#>

param(
    [int]$Port = 8318,
    [switch]$NoBrowser
)

$ErrorActionPreference = "Stop"

# Version
$SCRIPT_VERSION = "1.2.0"

# Paths
$SCRIPT_DIR = $PSScriptRoot
$GUI_PATH = Join-Path (Split-Path $SCRIPT_DIR -Parent) "gui\index.html"
$BIN_DIR = "$env:USERPROFILE\bin"
$CONFIG_DIR = "$env:USERPROFILE\.cliproxyapi"
$BINARY = "$BIN_DIR\cliproxyapi.exe"
$CONFIG = "$CONFIG_DIR\config.yaml"
$LOG_DIR = "$CONFIG_DIR\logs"
$API_PORT = 8317
$PROCESS_NAMES = @("cliproxyapi", "cli-proxy-api")

# Fallback GUI path
if (-not (Test-Path $GUI_PATH)) {
    $GUI_PATH = "$env:USERPROFILE\cliproxyapi\gui\index.html"
}

function Write-Log { param($msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $msg" }

function Get-ServerProcess {
    foreach ($name in $PROCESS_NAMES) {
        $proc = Get-Process -Name $name -ErrorAction SilentlyContinue
        if ($proc) { return $proc }
    }
    return $null
}

function Get-ServerStatus {
    $proc = Get-ServerProcess
    $running = $null -ne $proc
    
    $status = @{
        running   = $running
        pid       = if ($running) { $proc.Id } else { $null }
        memory    = if ($running) { [math]::Round($proc.WorkingSet64 / 1MB, 1) } else { $null }
        startTime = if ($running -and $proc.StartTime) { $proc.StartTime.ToString("o") } else { $null }
        port      = $API_PORT
        endpoint  = "http://localhost:$API_PORT/v1"
    }
    
    return $status
}

function Start-ApiServer {
    $proc = Get-ServerProcess
    if ($proc) {
        return @{ success = $false; error = "Server already running (PID: $($proc.Id))" }
    }
    
    if (-not (Test-Path $BINARY)) {
        return @{ success = $false; error = "Binary not found: $BINARY" }
    }
    
    if (-not (Test-Path $CONFIG)) {
        return @{ success = $false; error = "Config not found: $CONFIG" }
    }
    
    # Ensure log directory exists
    if (-not (Test-Path $LOG_DIR)) {
        New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null
    }
    
    try {
        $stdoutLog = Join-Path $LOG_DIR "server-stdout.log"
        $stderrLog = Join-Path $LOG_DIR "server-stderr.log"
        
        # Clear old logs on start
        if (Test-Path $stdoutLog) { Clear-Content $stdoutLog -Force }
        if (Test-Path $stderrLog) { Clear-Content $stderrLog -Force }
        $script:LastLogPosition = 0
        
        # Use ProcessStartInfo to properly redirect both streams
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $BINARY
        $psi.Arguments = "--config `"$CONFIG`""
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.WorkingDirectory = $CONFIG_DIR
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        [void]$process.Start()
        
        # Asynchronously redirect output to files
        Start-Job -ScriptBlock {
            param($p, $stdout, $stderr)
            while (-not $p.HasExited) {
                $line = $p.StandardOutput.ReadLine()
                if ($line) { $line | Out-File -Append -FilePath $stdout -Encoding UTF8 }
                $errLine = $p.StandardError.ReadLine()
                if ($errLine) { $errLine | Out-File -Append -FilePath $stderr -Encoding UTF8 }
            }
            # Capture remaining output
            $remaining = $p.StandardOutput.ReadToEnd()
            if ($remaining) { $remaining | Out-File -Append -FilePath $stdout -Encoding UTF8 }
            $errRemaining = $p.StandardError.ReadToEnd()
            if ($errRemaining) { $errRemaining | Out-File -Append -FilePath $stderr -Encoding UTF8 }
        } -ArgumentList $process, $stdoutLog, $stderrLog | Out-Null
        
        Start-Sleep -Milliseconds 500
        
        if (-not $process.HasExited) {
            return @{ success = $true; pid = $process.Id; message = "Server started" }
        }
        else {
            # Read error from logs
            $errorMsg = "Server exited immediately"
            $stdout = if (Test-Path $stdoutLog) { Get-Content $stdoutLog -Raw -ErrorAction SilentlyContinue } else { "" }
            $stderr = if (Test-Path $stderrLog) { Get-Content $stderrLog -Raw -ErrorAction SilentlyContinue } else { "" }
            $combinedLog = "$stdout$stderr".Trim()
            if ($combinedLog) { $errorMsg += ": $combinedLog" }
            return @{ success = $false; error = $errorMsg }
        }
    }
    catch {
        return @{ success = $false; error = $_.Exception.Message }
    }
}

function Stop-ApiServer {
    $proc = Get-ServerProcess
    if (-not $proc) {
        return @{ success = $false; error = "Server not running" }
    }
    
    try {
        $proc | Stop-Process -Force
        Start-Sleep -Milliseconds 300
        return @{ success = $true; message = "Server stopped" }
    }
    catch {
        return @{ success = $false; error = $_.Exception.Message }
    }
}

function Restart-ApiServer {
    Stop-ApiServer | Out-Null
    Start-Sleep -Milliseconds 500
    $startResult = Start-ApiServer
    return $startResult
}

function Start-OAuthLogin {
    param([string]$Provider)
    
    $flags = @{
        "gemini"      = "--login"
        "copilot"     = "--github-copilot-login"
        "antigravity" = "--antigravity-login"
        "codex"       = "--codex-login"
        "claude"      = "--claude-login"
        "qwen"        = "--qwen-login"
        "iflow"       = "--iflow-login"
        "kiro"        = "--kiro-aws-login"
    }
    
    if (-not $flags.ContainsKey($Provider.ToLower())) {
        return @{ success = $false; error = "Unknown provider: $Provider" }
    }
    
    $flag = $flags[$Provider.ToLower()]
    
    try {
        # Start OAuth in a new window so user can interact
        Start-Process -FilePath $BINARY -ArgumentList "--config `"$CONFIG`" $flag" -Wait:$false
        return @{ success = $true; message = "OAuth login started for $Provider" }
    }
    catch {
        return @{ success = $false; error = $_.Exception.Message }
    }
}

function Get-AuthStatus {
    # Check for auth token files to determine which providers are logged in
    $authPatterns = @{
        gemini      = "gemini-*.json"
        copilot     = "github-copilot-*.json"
        antigravity = "antigravity-*.json"
        codex       = "codex-*.json"
        claude      = "claude-*.json"
        qwen        = "qwen-*.json"
        iflow       = "iflow-*.json"
        kiro        = "kiro-*.json"
    }
    
    $status = @{}
    foreach ($provider in $authPatterns.Keys) {
        $pattern = Join-Path $CONFIG_DIR $authPatterns[$provider]
        $files = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
        $status[$provider] = ($null -ne $files -and $files.Count -gt 0)
    }
    
    return $status
}

function Get-ConfigContent {
    $configPath = "$env:USERPROFILE\.cliproxyapi\config.yaml"
    if (-not (Test-Path $configPath)) {
        return @{ success = $false; error = "Config file not found at: $configPath"; content = "" }
    }
    
    try {
        $content = [System.IO.File]::ReadAllText($configPath)
        return @{ success = $true; content = $content }
    }
    catch {
        return @{ success = $false; error = $_.Exception.Message; content = "" }
    }
}

function Set-ConfigContent {
    param([string]$Content)
    
    try {
        # Create backup
        $backupPath = "$CONFIG.bak"
        if (Test-Path $CONFIG) {
            Copy-Item -Path $CONFIG -Destination $backupPath -Force
        }
        
        # Write new content
        $Content | Out-File -FilePath $CONFIG -Encoding UTF8 -Force
        return @{ success = $true; message = "Config saved" }
    }
    catch {
        return @{ success = $false; error = $_.Exception.Message }
    }
}

function Get-AvailableModels {
    $proc = Get-ServerProcess
    if (-not $proc) {
        return @{ success = $false; error = "Server not running"; models = @() }
    }
    
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:$API_PORT/v1/models" -Headers @{ "Authorization" = "Bearer sk-dummy" } -TimeoutSec 5
        $models = @()
        if ($response.data) {
            $models = $response.data | ForEach-Object { $_.id }
        }
        return @{ success = $true; models = $models }
    }
    catch {
        return @{ success = $false; error = $_.Exception.Message; models = @() }
    }
}

# ============================================
# Request Stats Functions
# ============================================

$STATS_FILE = Join-Path $CONFIG_DIR "stats.json"

function Get-RequestStats {
    if (Test-Path $STATS_FILE) {
        try {
            $stats = Get-Content $STATS_FILE -Raw | ConvertFrom-Json
            $total = $(if ($stats.total_requests) { $stats.total_requests } else { 0 })
            $successful = $(if ($stats.successful) { $stats.successful } else { 0 })
            $failed = $(if ($stats.failed) { $stats.failed } else { 0 })
            $successRate = if ($total -gt 0) { [math]::Round(($successful / $total) * 100, 1) } else { 0 }
            $avgLatency = if ($stats.latencies -and $stats.latencies.Count -gt 0) { 
                [math]::Round(($stats.latencies | Measure-Object -Average).Average, 0)
            }
            else { 0 }
            
            return @{
                total        = $total
                successful   = $successful
                failed       = $failed
                successRate  = $successRate
                avgLatency   = $avgLatency
                available    = $true
                by_provider  = $stats.by_provider
                by_model     = $stats.by_model
                start_time   = $stats.start_time
                last_request = $stats.last_request
            }
        }
        catch { }
    }
    
    $defaultStats = @{
        total_requests = 0
        successful     = 0
        failed         = 0
        by_provider    = @{}
        by_model       = @{}
        latencies      = @()
        start_time     = (Get-Date).ToString("o")
        last_request   = $null
    }
    $defaultStats | ConvertTo-Json -Depth 10 | Out-File $STATS_FILE -Encoding UTF8
    
    return @{
        total        = 0
        successful   = 0
        failed       = 0
        successRate  = 0
        avgLatency   = 0
        available    = $true
        by_provider  = @{}
        by_model     = @{}
        start_time   = $defaultStats.start_time
        last_request = $null
    }
}

function Reset-RequestStats {
    $defaultStats = @{
        total_requests = 0
        successful     = 0
        failed         = 0
        by_provider    = @{}
        by_model       = @{}
        latencies      = @()
        start_time     = (Get-Date).ToString("o")
        last_request   = $null
    }
    $defaultStats | ConvertTo-Json -Depth 10 | Out-File $STATS_FILE -Encoding UTF8
    return @{ success = $true; message = "Stats reset" }
}

function Get-ServerLogs {
    param([int]$Lines = 100)
    
    $logFile = Join-Path $LOG_DIR "server.log"
    if (-not (Test-Path $logFile)) {
        return @{ success = $true; lines = @(); total = 0 }
    }
    
    try {
        $allLines = Get-Content $logFile -ErrorAction SilentlyContinue
        $total = if ($allLines) { $allLines.Count } else { 0 }
        $recent = if ($allLines -and $allLines.Count -gt $Lines) { 
            $allLines | Select-Object -Last $Lines 
        }
        else { 
            $allLines 
        }
        
        return @{
            success = $true
            lines   = @($recent)
            total   = $total
        }
    }
    catch {
        return @{ success = $false; error = $_.Exception.Message }
    }
}

# ============================================
# Auto-Update Functions
# ============================================

$VERSION_FILE = Join-Path $CONFIG_DIR "version.json"
$GITHUB_REPO = "imrosyd/cliproxyapi"

function Get-LocalVersion {
    if (Test-Path $VERSION_FILE) {
        try {
            $version = Get-Content $VERSION_FILE -Raw | ConvertFrom-Json
            # Ensure commitSha field exists (for existing users)
            if (-not $version.commitSha) {
                $version | Add-Member -NotePropertyName "commitSha" -NotePropertyValue "unknown" -Force
            }
            return $version
        }
        catch { }
    }
    
    # Create default version file
    $defaultVersion = @{
        scripts    = $SCRIPT_VERSION
        commitSha  = "unknown"
        commitDate = $null
        lastCheck  = $null
    }
    $defaultVersion | ConvertTo-Json | Out-File $VERSION_FILE -Encoding UTF8
    return $defaultVersion
}

function Get-UpdateInfo {
    $local = Get-LocalVersion
    
    $result = @{
        currentVersion      = $local.scripts
        currentCommit       = $local.commitSha
        latestCommit        = $null
        latestCommitDate    = $null
        latestCommitMessage = ""
        hasUpdate           = $false
        downloadUrl         = "https://github.com/$GITHUB_REPO/archive/refs/heads/main.zip"
        repoUrl             = "https://github.com/$GITHUB_REPO"
        error               = $null
    }
    
    try {
        # Check latest commit on main branch
        $headers = @{ "User-Agent" = "CLIProxyAPI-Updater" }
        $apiUrl = "https://api.github.com/repos/$GITHUB_REPO/commits/main"
        
        $commit = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        
        $result.latestCommit = $commit.sha.Substring(0, 7)
        $result.latestCommitDate = $commit.commit.author.date
        # Get first line of commit message
        $result.latestCommitMessage = ($commit.commit.message -split "`n")[0]
        
        # Has update if commit SHA is different (and not unknown)
        if ($local.commitSha -eq "unknown") {
            $result.hasUpdate = $true
        }
        else {
            $result.hasUpdate = ($local.commitSha -ne $result.latestCommit)
        }
        
        # Update last check time
        $local.lastCheck = (Get-Date).ToString("o")
        $local | ConvertTo-Json | Out-File $VERSION_FILE -Encoding UTF8
        
    }
    catch {
        $result.error = $_.Exception.Message
    }
    
    return $result
}

function Install-Update {
    # Use main branch archive URL directly
    $downloadUrl = "https://github.com/$GITHUB_REPO/archive/refs/heads/main.zip"
    
    try {
        # Get latest commit info first
        $updateInfo = Get-UpdateInfo
        if ($updateInfo.error) {
            return @{ success = $false; error = "Failed to get update info: $($updateInfo.error)" }
        }
        
        # Stop server if running
        $proc = Get-ServerProcess
        $wasRunning = $null -ne $proc
        if ($wasRunning) {
            Stop-ApiServer | Out-Null
            Start-Sleep -Seconds 1
        }
        
        # Download to temp
        $tempDir = Join-Path $env:TEMP "cliproxyapi-update"
        $zipFile = Join-Path $tempDir "update.zip"
        
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        Write-Log "Downloading update from $downloadUrl"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile -UseBasicParsing
        
        # Extract
        Write-Log "Extracting update..."
        Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force
        
        # Find extracted folder (GitHub archives as repo-name-branch)
        $extractedFolder = Get-ChildItem -Path $tempDir -Directory | Select-Object -First 1
        if (-not $extractedFolder) {
            $extractedFolder = Get-Item $tempDir
        }
        
        # Copy scripts
        $scriptsSource = Join-Path $extractedFolder.FullName "scripts"
        if (Test-Path $scriptsSource) {
            Copy-Item -Path "$scriptsSource\*" -Destination $BIN_DIR -Force -Recurse
        }
        
        # Copy GUI
        $guiSource = Join-Path $extractedFolder.FullName "gui"
        $guiDest = Split-Path $GUI_PATH -Parent
        if (Test-Path $guiSource) {
            Copy-Item -Path "$guiSource\*" -Destination $guiDest -Force -Recurse
        }
        
        # Update version file with new commit SHA
        $local = Get-LocalVersion
        $local.commitSha = $updateInfo.latestCommit
        $local.commitDate = $updateInfo.latestCommitDate
        $local | ConvertTo-Json | Out-File $VERSION_FILE -Encoding UTF8
        
        # Cleanup
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        
        # Restart server if it was running
        if ($wasRunning) {
            Start-ApiServer | Out-Null
        }
        
        return @{ 
            success       = $true
            message       = "Update installed successfully"
            newCommit     = $updateInfo.latestCommit
            commitMessage = $updateInfo.latestCommitMessage
            needsRestart  = $true
        }
    }
    catch {
        return @{ success = $false; error = $_.Exception.Message }
    }
}

# ============================================
# Factory Config Functions
# ============================================

$FACTORY_CONFIG_PATH = "$env:USERPROFILE\.factory\config.json"

function Get-FactoryConfig {
    if (-not (Test-Path $FACTORY_CONFIG_PATH)) {
        return @{ success = $true; config = @{ custom_models = @() }; models = @() }
    }
    
    try {
        $content = Get-Content $FACTORY_CONFIG_PATH -Raw -Encoding UTF8
        $config = $content | ConvertFrom-Json
        $models = @()
        if ($config.custom_models) {
            $models = $config.custom_models | ForEach-Object {
                @{
                    model        = $_.model
                    display_name = $_.model_display_name
                    base_url     = $_.base_url
                }
            }
        }
        return @{ success = $true; config = $config; models = $models }
    }
    catch {
        return @{ success = $false; error = $_.Exception.Message; models = @() }
    }
}

function Add-FactoryModels {
    param([array]$Models, [hashtable]$DisplayNames)
    
    try {
        # Ensure .factory directory exists
        $factoryDir = Split-Path $FACTORY_CONFIG_PATH -Parent
        if (-not (Test-Path $factoryDir)) {
            New-Item -ItemType Directory -Path $factoryDir -Force | Out-Null
        }
        
        # Load existing config or create new
        $config = @{ custom_models = @() }
        if (Test-Path $FACTORY_CONFIG_PATH) {
            $backup = "$FACTORY_CONFIG_PATH.bak"
            Copy-Item -Path $FACTORY_CONFIG_PATH -Destination $backup -Force
            $content = Get-Content $FACTORY_CONFIG_PATH -Raw -Encoding UTF8
            $config = $content | ConvertFrom-Json
            if (-not $config.custom_models) {
                $config | Add-Member -NotePropertyName "custom_models" -NotePropertyValue @() -Force
            }
        }
        
        # Get existing model IDs
        $existingModels = @()
        if ($config.custom_models) {
            $existingModels = $config.custom_models | ForEach-Object { $_.model }
        }
        
        # Add new models
        $added = @()
        foreach ($modelId in $Models) {
            if ($modelId -notin $existingModels) {
                $displayName = if ($DisplayNames -and $DisplayNames[$modelId]) { 
                    $DisplayNames[$modelId] 
                }
                else { 
                    $modelId 
                }
                
                $newEntry = @{
                    api_key            = "sk-dummy"
                    provider           = "openai"
                    model              = $modelId
                    base_url           = "http://localhost:8317/v1"
                    model_display_name = $displayName
                }
                
                $config.custom_models += $newEntry
                $added += $modelId
            }
        }
        
        # Save config
        $config | ConvertTo-Json -Depth 10 | Out-File -FilePath $FACTORY_CONFIG_PATH -Encoding UTF8 -Force
        
        return @{ success = $true; added = $added; total = $config.custom_models.Count }
    }
    catch {
        return @{ success = $false; error = $_.Exception.Message }
    }
}

function Remove-FactoryModels {
    param([array]$Models, [switch]$All)
    
    if (-not (Test-Path $FACTORY_CONFIG_PATH)) {
        return @{ success = $false; error = "Config file not found" }
    }
    
    try {
        # Backup
        $backup = "$FACTORY_CONFIG_PATH.bak"
        Copy-Item -Path $FACTORY_CONFIG_PATH -Destination $backup -Force
        
        $content = Get-Content $FACTORY_CONFIG_PATH -Raw -Encoding UTF8
        $config = $content | ConvertFrom-Json
        
        if (-not $config.custom_models) {
            return @{ success = $true; removed = @(); total = 0 }
        }
        
        $removed = @()
        if ($All) {
            $removed = $config.custom_models | ForEach-Object { $_.model }
            $config.custom_models = @()
        }
        else {
            $remaining = @()
            foreach ($entry in $config.custom_models) {
                if ($entry.model -in $Models) {
                    $removed += $entry.model
                }
                else {
                    $remaining += $entry
                }
            }
            $config.custom_models = $remaining
        }
        
        # Save config
        $config | ConvertTo-Json -Depth 10 | Out-File -FilePath $FACTORY_CONFIG_PATH -Encoding UTF8 -Force
        
        return @{ success = $true; removed = $removed; total = $config.custom_models.Count }
    }
    catch {
        return @{ success = $false; error = $_.Exception.Message }
    }
}

function Send-JsonResponse {
    param($Context, $Data, [int]$StatusCode = 200)
    
    $json = $Data | ConvertTo-Json -Depth 5
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
    
    $Context.Response.StatusCode = $StatusCode
    $Context.Response.ContentType = "application/json"
    $Context.Response.Headers.Add("Access-Control-Allow-Origin", "*")
    $Context.Response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    $Context.Response.Headers.Add("Access-Control-Allow-Headers", "Content-Type")
    $Context.Response.ContentLength64 = $buffer.Length
    $Context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
    $Context.Response.OutputStream.Close()
}

function Send-HtmlResponse {
    param($Context, $HtmlPath)
    
    if (-not (Test-Path $HtmlPath)) {
        $Context.Response.StatusCode = 404
        $buffer = [System.Text.Encoding]::UTF8.GetBytes("GUI not found")
        $Context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
        $Context.Response.OutputStream.Close()
        return
    }
    
    $html = Get-Content -Path $HtmlPath -Raw -Encoding UTF8
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
    
    $Context.Response.StatusCode = 200
    $Context.Response.ContentType = "text/html; charset=utf-8"
    $Context.Response.ContentLength64 = $buffer.Length
    $Context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
    $Context.Response.OutputStream.Close()
}

# Main
Write-Host @"

============================================
  CLIProxyAPI+ Control Center
============================================
"@ -ForegroundColor Magenta

# Check if GUI exists
if (-not (Test-Path $GUI_PATH)) {
    Write-Host "[-] GUI not found at: $GUI_PATH" -ForegroundColor Red
    exit 1
}

# Auto-cleanup orphaned GUI process and find available port
$originalPort = $Port
$maxRetries = 5
$portFound = $false

for ($i = 0; $i -lt $maxRetries; $i++) {
    $testPort = $originalPort + $i
    $existingConn = Get-NetTCPConnection -LocalPort $testPort -ErrorAction SilentlyContinue
    
    if ($existingConn) {
        # Try to kill orphaned PowerShell GUI process
        $proc = Get-Process -Id $existingConn.OwningProcess -ErrorAction SilentlyContinue
        if ($proc -and ($proc.ProcessName -eq "pwsh" -or $proc.ProcessName -eq "powershell")) {
            Write-Host "[!] Killing orphaned GUI process on port $testPort (PID: $($proc.Id))..." -ForegroundColor Yellow
            $proc | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
            
            # Re-check if port is now free
            $stillInUse = Get-NetTCPConnection -LocalPort $testPort -ErrorAction SilentlyContinue
            if (-not $stillInUse) {
                $Port = $testPort
                $portFound = $true
                break
            }
        }
        # Port still in use by another process, try next port
        if ($i -eq 0) {
            Write-Host "[!] Port $testPort in use, trying alternatives..." -ForegroundColor Yellow
        }
    }
    else {
        $Port = $testPort
        $portFound = $true
        break
    }
}

if (-not $portFound) {
    Write-Host "[-] No available port found (tried $originalPort-$($originalPort + $maxRetries - 1))" -ForegroundColor Red
    exit 1
}

if ($Port -ne $originalPort) {
    Write-Host "[+] Using port $Port (default $originalPort was busy)" -ForegroundColor Cyan
}

# Create HTTP listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")

# Setup graceful shutdown handler
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    if ($listener -and $listener.IsListening) {
        $listener.Stop()
        $listener.Close()
    }
} -ErrorAction SilentlyContinue

try {
    $listener.Start()
    Write-Log "Management server started on http://localhost:$Port"
    Write-Host ""
    Write-Host "  GUI:      http://localhost:$Port" -ForegroundColor Cyan
    Write-Host "  API:      http://localhost:$Port/api/*" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
    Write-Host ""
    
    # Open browser
    if (-not $NoBrowser) {
        Start-Process "http://localhost:$Port"
    }
    
    # Request loop
    while ($listener.IsListening) {
        try {
            $context = $listener.GetContext()
            $request = $context.Request
            $path = $request.Url.LocalPath
            $method = $request.HttpMethod
            
            Write-Log "$method $path"
            
            # Handle CORS preflight
            if ($method -eq "OPTIONS") {
                $context.Response.Headers.Add("Access-Control-Allow-Origin", "*")
                $context.Response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
                $context.Response.Headers.Add("Access-Control-Allow-Headers", "Content-Type")
                $context.Response.StatusCode = 204
                $context.Response.OutputStream.Close()
                continue
            }
            
            # Route requests
            switch -Regex ($path) {
                "^/$" {
                    Send-HtmlResponse -Context $context -HtmlPath $GUI_PATH
                }
                "^/api/status$" {
                    $status = Get-ServerStatus
                    Send-JsonResponse -Context $context -Data $status
                }
                "^/api/auth-status$" {
                    $authStatus = Get-AuthStatus
                    Send-JsonResponse -Context $context -Data $authStatus
                }
                "^/api/models$" {
                    $models = Get-AvailableModels
                    Send-JsonResponse -Context $context -Data $models
                }
                "^/api/config$" {
                    if ($method -eq "GET") {
                        $config = Get-ConfigContent
                        Send-JsonResponse -Context $context -Data $config
                    }
                    elseif ($method -eq "POST") {
                        # Read request body
                        $reader = New-Object System.IO.StreamReader($request.InputStream)
                        $body = $reader.ReadToEnd()
                        $reader.Close()
                        
                        try {
                            $data = $body | ConvertFrom-Json
                            $result = Set-ConfigContent -Content $data.content
                            Send-JsonResponse -Context $context -Data $result
                        }
                        catch {
                            Send-JsonResponse -Context $context -Data @{ success = $false; error = "Invalid JSON" } -StatusCode 400
                        }
                    }
                    else {
                        Send-JsonResponse -Context $context -Data @{ error = "Method not allowed" } -StatusCode 405
                    }
                }
                "^/api/start$" {
                    if ($method -eq "POST") {
                        $result = Start-ApiServer
                        Send-JsonResponse -Context $context -Data $result
                    }
                    else {
                        Send-JsonResponse -Context $context -Data @{ error = "Method not allowed" } -StatusCode 405
                    }
                }
                "^/api/stop$" {
                    if ($method -eq "POST") {
                        $result = Stop-ApiServer
                        Send-JsonResponse -Context $context -Data $result
                    }
                    else {
                        Send-JsonResponse -Context $context -Data @{ error = "Method not allowed" } -StatusCode 405
                    }
                }
                "^/api/restart$" {
                    if ($method -eq "POST") {
                        $result = Restart-ApiServer
                        Send-JsonResponse -Context $context -Data $result
                    }
                    else {
                        Send-JsonResponse -Context $context -Data @{ error = "Method not allowed" } -StatusCode 405
                    }
                }
                "^/api/oauth/(.+)$" {
                    if ($method -eq "POST") {
                        $provider = $matches[1]
                        $result = Start-OAuthLogin -Provider $provider
                        Send-JsonResponse -Context $context -Data $result
                    }
                    else {
                        Send-JsonResponse -Context $context -Data @{ error = "Method not allowed" } -StatusCode 405
                    }
                }
                "^/api/stats$" {
                    if ($method -eq "GET") {
                        $stats = Get-RequestStats
                        Send-JsonResponse -Context $context -Data $stats
                    }
                    elseif ($method -eq "DELETE") {
                        $result = Reset-RequestStats
                        Send-JsonResponse -Context $context -Data $result
                    }
                    else {
                        Send-JsonResponse -Context $context -Data @{ error = "Method not allowed" } -StatusCode 405
                    }
                }
                "^/api/logs$" {
                    if ($method -eq "GET") {
                        $lines = 100
                        if ($request.Url.Query -match "lines=(\d+)") {
                            $lines = [int]$matches[1]
                        }
                        $logs = Get-ServerLogs -Lines $lines
                        Send-JsonResponse -Context $context -Data $logs
                    }
                    else {
                        Send-JsonResponse -Context $context -Data @{ error = "Method not allowed" } -StatusCode 405
                    }
                }
                "^/api/update/check$" {
                    $updateInfo = Get-UpdateInfo
                    Send-JsonResponse -Context $context -Data $updateInfo
                }
                "^/api/update/apply$" {
                    if ($method -eq "POST") {
                        # Read request body for download URL
                        $reader = New-Object System.IO.StreamReader($request.InputStream)
                        $body = $reader.ReadToEnd()
                        $reader.Close()
                        
                        $downloadUrl = $null
                        if ($body) {
                            try {
                                $data = $body | ConvertFrom-Json
                                $downloadUrl = $data.downloadUrl
                            }
                            catch { }
                        }
                        
                        # If no URL provided, get it from update check
                        if (-not $downloadUrl) {
                            $updateInfo = Get-UpdateInfo
                            $downloadUrl = $updateInfo.downloadUrl
                        }
                        
                        $result = Install-Update -DownloadUrl $downloadUrl
                        Send-JsonResponse -Context $context -Data $result
                    }
                    else {
                        Send-JsonResponse -Context $context -Data @{ error = "Method not allowed" } -StatusCode 405
                    }
                }
                "^/api/version$" {
                    $version = Get-LocalVersion
                    $version | Add-Member -NotePropertyName "scriptVersion" -NotePropertyValue $SCRIPT_VERSION -Force
                    Send-JsonResponse -Context $context -Data $version
                }
                "^/api/factory-config$" {
                    if ($method -eq "GET") {
                        $result = Get-FactoryConfig
                        Send-JsonResponse -Context $context -Data $result
                    }
                    else {
                        Send-JsonResponse -Context $context -Data @{ error = "Method not allowed" } -StatusCode 405
                    }
                }
                "^/api/factory-config/add$" {
                    if ($method -eq "POST") {
                        $reader = New-Object System.IO.StreamReader($request.InputStream)
                        $body = $reader.ReadToEnd()
                        $reader.Close()
                        
                        try {
                            $data = $body | ConvertFrom-Json
                            $models = @($data.models)
                            $displayNames = @{}
                            if ($data.displayNames) {
                                $data.displayNames.PSObject.Properties | ForEach-Object {
                                    $displayNames[$_.Name] = $_.Value
                                }
                            }
                            $result = Add-FactoryModels -Models $models -DisplayNames $displayNames
                            Send-JsonResponse -Context $context -Data $result
                        }
                        catch {
                            Send-JsonResponse -Context $context -Data @{ success = $false; error = "Invalid request: $($_.Exception.Message)" } -StatusCode 400
                        }
                    }
                    else {
                        Send-JsonResponse -Context $context -Data @{ error = "Method not allowed" } -StatusCode 405
                    }
                }
                "^/api/factory-config/remove$" {
                    if ($method -eq "POST") {
                        $reader = New-Object System.IO.StreamReader($request.InputStream)
                        $body = $reader.ReadToEnd()
                        $reader.Close()
                        
                        try {
                            $data = $body | ConvertFrom-Json
                            if ($data.all -eq $true) {
                                $result = Remove-FactoryModels -All
                            }
                            else {
                                $models = @($data.models)
                                $result = Remove-FactoryModels -Models $models
                            }
                            Send-JsonResponse -Context $context -Data $result
                        }
                        catch {
                            Send-JsonResponse -Context $context -Data @{ success = $false; error = "Invalid request: $($_.Exception.Message)" } -StatusCode 400
                        }
                    }
                    else {
                        Send-JsonResponse -Context $context -Data @{ error = "Method not allowed" } -StatusCode 405
                    }
                }
                "^/api/management/usage$" {
                    if ($method -eq "GET") {
                        try {
                            $usageData = Invoke-RestMethod -Uri "http://localhost:8317/v0/management/usage" -Method GET -TimeoutSec 5 -ErrorAction Stop
                            Send-JsonResponse -Context $context -Data $usageData
                        }
                        catch {
                            try {
                                $headers = @{ "Authorization" = "Bearer sk-dummy" }
                                $usageData = Invoke-RestMethod -Uri "http://localhost:8317/v0/management/usage" -Method GET -Headers $headers -TimeoutSec 5 -ErrorAction Stop
                                Send-JsonResponse -Context $context -Data $usageData
                            }
                            catch {
                                Send-JsonResponse -Context $context -Data @{ available = $false; error = "Management API not available. Enable usage-statistics-enabled in config.yaml" }
                            }
                        }
                    }
                    else {
                        Send-JsonResponse -Context $context -Data @{ error = "Method not allowed" } -StatusCode 405
                    }
                }
                default {
                    Send-JsonResponse -Context $context -Data @{ error = "Not found" } -StatusCode 404
                }
            }
        }
        catch {
            Write-Host "[-] Request error: $_" -ForegroundColor Red
        }
    }
}
catch {
    Write-Host "[-] Server error: $_" -ForegroundColor Red
}
finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
    $listener.Close()
    Write-Log "Server stopped"
}
