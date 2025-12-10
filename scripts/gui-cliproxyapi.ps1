<#
.SYNOPSIS
    CLIProxyAPI-Plus GUI Control Center with Management Server
.DESCRIPTION
    Starts an HTTP management server that serves the GUI and provides API endpoints
    for controlling the CLIProxyAPI-Plus server (start/stop/restart/oauth).
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
$SCRIPT_VERSION = "1.1.0"

# Paths
$SCRIPT_DIR = $PSScriptRoot
$GUI_PATH = Join-Path (Split-Path $SCRIPT_DIR -Parent) "gui\index.html"
$BIN_DIR = "$env:USERPROFILE\bin"
$CONFIG_DIR = "$env:USERPROFILE\.cli-proxy-api"
$BINARY = "$BIN_DIR\cliproxyapi-plus.exe"
$CONFIG = "$CONFIG_DIR\config.yaml"
$LOG_DIR = "$CONFIG_DIR\logs"
$API_PORT = 8317
$PROCESS_NAMES = @("cliproxyapi-plus", "cli-proxy-api")

# Fallback GUI path
if (-not (Test-Path $GUI_PATH)) {
    $GUI_PATH = "$env:USERPROFILE\CLIProxyAPIPlus-Easy-Installation\gui\index.html"
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
        running = $running
        pid = if ($running) { $proc.Id } else { $null }
        memory = if ($running) { [math]::Round($proc.WorkingSet64 / 1MB, 1) } else { $null }
        startTime = if ($running -and $proc.StartTime) { $proc.StartTime.ToString("o") } else { $null }
        port = $API_PORT
        endpoint = "http://localhost:$API_PORT/v1"
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
        } else {
            # Read error from logs
            $errorMsg = "Server exited immediately"
            $stdout = if (Test-Path $stdoutLog) { Get-Content $stdoutLog -Raw -ErrorAction SilentlyContinue } else { "" }
            $stderr = if (Test-Path $stderrLog) { Get-Content $stderrLog -Raw -ErrorAction SilentlyContinue } else { "" }
            $combinedLog = "$stdout$stderr".Trim()
            if ($combinedLog) { $errorMsg += ": $combinedLog" }
            return @{ success = $false; error = $errorMsg }
        }
    } catch {
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
    } catch {
        return @{ success = $false; error = $_.Exception.Message }
    }
}

function Restart-ApiServer {
    $stopResult = Stop-ApiServer
    Start-Sleep -Milliseconds 500
    $startResult = Start-ApiServer
    return $startResult
}

function Start-OAuthLogin {
    param([string]$Provider)
    
    $flags = @{
        "gemini" = "--login"
        "copilot" = "--github-copilot-login"
        "antigravity" = "--antigravity-login"
        "codex" = "--codex-login"
        "claude" = "--claude-login"
        "qwen" = "--qwen-login"
        "iflow" = "--iflow-login"
        "kiro" = "--kiro-aws-login"
    }
    
    if (-not $flags.ContainsKey($Provider.ToLower())) {
        return @{ success = $false; error = "Unknown provider: $Provider" }
    }
    
    $flag = $flags[$Provider.ToLower()]
    
    try {
        # Start OAuth in a new window so user can interact
        Start-Process -FilePath $BINARY -ArgumentList "--config `"$CONFIG`" $flag" -Wait:$false
        return @{ success = $true; message = "OAuth login started for $Provider" }
    } catch {
        return @{ success = $false; error = $_.Exception.Message }
    }
}

function Get-AuthStatus {
    # Check for auth token files to determine which providers are logged in
    $authPatterns = @{
        gemini = "gemini-*.json"
        copilot = "github-copilot-*.json"
        antigravity = "antigravity-*.json"
        codex = "codex-*.json"
        claude = "claude-*.json"
        qwen = "qwen-*.json"
        iflow = "iflow-*.json"
        kiro = "kiro-*.json"
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
    $configPath = "$env:USERPROFILE\.cli-proxy-api\config.yaml"
    if (-not (Test-Path $configPath)) {
        return @{ success = $false; error = "Config file not found at: $configPath"; content = "" }
    }
    
    try {
        $content = [System.IO.File]::ReadAllText($configPath)
        return @{ success = $true; content = $content }
    } catch {
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
    } catch {
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
    } catch {
        return @{ success = $false; error = $_.Exception.Message; models = @() }
    }
}

# ============================================
# Request Stats Functions
# ============================================

function Get-RequestStats {
    # CLIProxyAPI doesn't output access logs to stdout/stderr by default
    # Stats tracking would require intercepting requests or reading from a stats endpoint
    # For now, return placeholder data indicating stats are not available
    
    # Check if server has a /stats endpoint
    $proc = Get-ServerProcess
    if ($proc) {
        try {
            # Try to fetch stats from server's internal stats endpoint if available
            $response = Invoke-RestMethod -Uri "http://localhost:$API_PORT/stats" -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($response) {
                return @{
                    total = $response.total_requests ?? 0
                    success = $response.successful_requests ?? 0
                    errors = $response.failed_requests ?? 0
                    successRate = if ($response.total_requests -gt 0) { [math]::Round(($response.successful_requests / $response.total_requests) * 100, 1) } else { 0 }
                    avgLatency = $response.avg_latency_ms ?? 0
                    lastReset = $response.start_time ?? (Get-Date).ToString("o")
                    available = $true
                }
            }
        } catch {
            # Stats endpoint not available
        }
    }
    
    # Return unavailable stats
    return @{
        total = 0
        success = 0
        errors = 0
        successRate = 0
        avgLatency = 0
        lastReset = (Get-Date).ToString("o")
        available = $false
        message = "Stats not available - CLIProxyAPI doesn't expose request metrics"
    }
}

function Reset-RequestStats {
    # Stats are fetched from server, cannot be reset from GUI
    return @{ success = $false; message = "Stats reset not supported - stats are read-only from server" }
}

# ============================================
# Auto-Update Functions
# ============================================

$VERSION_FILE = Join-Path $CONFIG_DIR "version.json"
$GITHUB_REPO = "julianromli/CLIProxyAPIPlus-Easy-Installation"
$UPSTREAM_REPO = "router-for-me/CLIProxyAPIPlus"

function Get-LocalVersion {
    if (Test-Path $VERSION_FILE) {
        try {
            return Get-Content $VERSION_FILE -Raw | ConvertFrom-Json
        } catch { }
    }
    
    # Create default version file
    $defaultVersion = @{
        scripts = $SCRIPT_VERSION
        binary = "unknown"
        lastCheck = $null
    }
    $defaultVersion | ConvertTo-Json | Out-File $VERSION_FILE -Encoding UTF8
    return $defaultVersion
}

function Get-UpdateInfo {
    $local = Get-LocalVersion
    
    $result = @{
        currentVersion = $local.scripts
        latestVersion = $local.scripts
        hasUpdate = $false
        releaseNotes = ""
        releaseUrl = ""
        downloadUrl = ""
        error = $null
    }
    
    try {
        # Check our repo for script updates
        $headers = @{ "User-Agent" = "CLIProxyAPI-Plus-Updater" }
        $releaseUrl = "https://api.github.com/repos/$GITHUB_REPO/releases/latest"
        
        $release = Invoke-RestMethod -Uri $releaseUrl -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        
        $result.latestVersion = $release.tag_name -replace "^v", ""
        $result.releaseNotes = $release.body
        $result.releaseUrl = $release.html_url
        
        # Find download URL (zip asset)
        $zipAsset = $release.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
        if ($zipAsset) {
            $result.downloadUrl = $zipAsset.browser_download_url
        }
        
        # Compare versions
        try {
            $currentVer = [version]($local.scripts -replace "[^0-9.]", "")
            $latestVer = [version]($result.latestVersion -replace "[^0-9.]", "")
            $result.hasUpdate = $latestVer -gt $currentVer
        } catch {
            $result.hasUpdate = $local.scripts -ne $result.latestVersion
        }
        
        # Update last check time
        $local.lastCheck = (Get-Date).ToString("o")
        $local | ConvertTo-Json | Out-File $VERSION_FILE -Encoding UTF8
        
    } catch {
        $result.error = $_.Exception.Message
    }
    
    return $result
}

function Install-Update {
    param([string]$DownloadUrl)
    
    if (-not $DownloadUrl) {
        return @{ success = $false; error = "No download URL provided" }
    }
    
    try {
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
        
        Write-Log "Downloading update from $DownloadUrl"
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $zipFile -UseBasicParsing
        
        # Extract
        Write-Log "Extracting update..."
        Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force
        
        # Find extracted folder
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
        
        # Update version file
        $local = Get-LocalVersion
        $updateInfo = Get-UpdateInfo
        $local.scripts = $updateInfo.latestVersion
        $local | ConvertTo-Json | Out-File $VERSION_FILE -Encoding UTF8
        
        # Cleanup
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        
        # Restart server if it was running
        if ($wasRunning) {
            Start-ApiServer | Out-Null
        }
        
        return @{ 
            success = $true
            message = "Update installed successfully"
            newVersion = $updateInfo.latestVersion
            needsRestart = $true
        }
    } catch {
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

# Check if port is available
$portInUse = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
if ($portInUse) {
    Write-Host "[-] Port $Port already in use" -ForegroundColor Red
    exit 1
}

# Create HTTP listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")

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
                    } elseif ($method -eq "POST") {
                        # Read request body
                        $reader = New-Object System.IO.StreamReader($request.InputStream)
                        $body = $reader.ReadToEnd()
                        $reader.Close()
                        
                        try {
                            $data = $body | ConvertFrom-Json
                            $result = Set-ConfigContent -Content $data.content
                            Send-JsonResponse -Context $context -Data $result
                        } catch {
                            Send-JsonResponse -Context $context -Data @{ success = $false; error = "Invalid JSON" } -StatusCode 400
                        }
                    } else {
                        Send-JsonResponse -Context $context -Data @{ error = "Method not allowed" } -StatusCode 405
                    }
                }
                "^/api/start$" {
                    if ($method -eq "POST") {
                        $result = Start-ApiServer
                        Send-JsonResponse -Context $context -Data $result
                    } else {
                        Send-JsonResponse -Context $context -Data @{ error = "Method not allowed" } -StatusCode 405
                    }
                }
                "^/api/stop$" {
                    if ($method -eq "POST") {
                        $result = Stop-ApiServer
                        Send-JsonResponse -Context $context -Data $result
                    } else {
                        Send-JsonResponse -Context $context -Data @{ error = "Method not allowed" } -StatusCode 405
                    }
                }
                "^/api/restart$" {
                    if ($method -eq "POST") {
                        $result = Restart-ApiServer
                        Send-JsonResponse -Context $context -Data $result
                    } else {
                        Send-JsonResponse -Context $context -Data @{ error = "Method not allowed" } -StatusCode 405
                    }
                }
                "^/api/oauth/(.+)$" {
                    if ($method -eq "POST") {
                        $provider = $matches[1]
                        $result = Start-OAuthLogin -Provider $provider
                        Send-JsonResponse -Context $context -Data $result
                    } else {
                        Send-JsonResponse -Context $context -Data @{ error = "Method not allowed" } -StatusCode 405
                    }
                }
                "^/api/stats$" {
                    if ($method -eq "GET") {
                        $stats = Get-RequestStats
                        Send-JsonResponse -Context $context -Data $stats
                    } elseif ($method -eq "DELETE") {
                        $result = Reset-RequestStats
                        Send-JsonResponse -Context $context -Data $result
                    } else {
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
                            } catch { }
                        }
                        
                        # If no URL provided, get it from update check
                        if (-not $downloadUrl) {
                            $updateInfo = Get-UpdateInfo
                            $downloadUrl = $updateInfo.downloadUrl
                        }
                        
                        $result = Install-Update -DownloadUrl $downloadUrl
                        Send-JsonResponse -Context $context -Data $result
                    } else {
                        Send-JsonResponse -Context $context -Data @{ error = "Method not allowed" } -StatusCode 405
                    }
                }
                "^/api/version$" {
                    $version = Get-LocalVersion
                    $version | Add-Member -NotePropertyName "scriptVersion" -NotePropertyValue $SCRIPT_VERSION -Force
                    Send-JsonResponse -Context $context -Data $version
                }
                default {
                    Send-JsonResponse -Context $context -Data @{ error = "Not found" } -StatusCode 404
                }
            }
        } catch {
            Write-Host "[-] Request error: $_" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "[-] Server error: $_" -ForegroundColor Red
} finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
    $listener.Close()
    Write-Log "Server stopped"
}
