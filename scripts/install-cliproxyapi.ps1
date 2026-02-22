<#
.SYNOPSIS
    CLIProxyAPI Installation Script for Droid CLI
.DESCRIPTION
    Complete one-click installer that sets up CLIProxyAPI for Factory Droid.
    - Clones or downloads pre-built binary
    - Configures ~/.cliproxyapi/config.yaml
    - Updates ~/.factory/config.json with custom models
    - Provides OAuth login prompts
.NOTES
    Author: Auto-generated for faiz
    Repo: https://github.com/imrosyd/cliproxyapi
#>

param(
    [switch]$UsePrebuilt,
    [switch]$SkipOAuth,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$REPO_URL = "https://github.com/router-for-me/CLIProxyAPIPlus.git"
$RELEASE_API = "https://api.github.com/repos/router-for-me/CLIProxyAPIPlus/releases/latest"
$CLONE_DIR = "$env:USERPROFILE\CLIProxyAPI-source"
$BIN_DIR = "$env:USERPROFILE\bin"
$CONFIG_DIR = "$env:USERPROFILE\.cliproxyapi"
$FACTORY_DIR = "$env:USERPROFILE\.factory"
$BINARY_NAME = "cliproxyapi.exe"

function Write-Step { param($msg) Write-Host "`n[*] $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "[+] $msg" -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "[-] $msg" -ForegroundColor Red }

Write-Host @"
==============================================
  CLIProxyAPI Installer for Droid CLI
==============================================
"@ -ForegroundColor Magenta

# Check prerequisites
Write-Step "Checking prerequisites..."

# Check Go (only if not using prebuilt)
if (-not $UsePrebuilt) {
    $goVersion = & go version 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Go is not installed. Switching to prebuilt binary mode."
        $UsePrebuilt = $true
    } else {
        Write-Success "Go found: $goVersion"
    }
}

# Check Git
$gitVersion = & git --version 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Git is not installed. Please install Git first."
    exit 1
}
Write-Success "Git found: $gitVersion"

# Create directories
Write-Step "Creating directories..."
if (-not (Test-Path $BIN_DIR)) { New-Item -ItemType Directory -Path $BIN_DIR -Force | Out-Null }
if (-not (Test-Path $CONFIG_DIR)) { New-Item -ItemType Directory -Path $CONFIG_DIR -Force | Out-Null }
if (-not (Test-Path $FACTORY_DIR)) { New-Item -ItemType Directory -Path $FACTORY_DIR -Force | Out-Null }
Write-Success "Directories ready"

# Install binary
if ($UsePrebuilt) {
    Write-Step "Downloading pre-built binary from GitHub Releases..."
    try {
        $release = Invoke-RestMethod -Uri $RELEASE_API -Headers @{"User-Agent"="PowerShell"}
        $asset = $release.assets | Where-Object { $_.name -like "*windows_amd64.zip" } | Select-Object -First 1
        if (-not $asset) {
            Write-Error "Could not find Windows binary in latest release"
            exit 1
        }
        $zipPath = "$env:TEMP\cliproxyapi.zip"
        $extractPath = "$env:TEMP\cliproxyapi-extract"
        
        Write-Host "    Downloading $($asset.name)..."
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath
        
        if (Test-Path $extractPath) { Remove-Item -Recurse -Force $extractPath }
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        
        $exeFile = Get-ChildItem -Path $extractPath -Recurse -Filter "*.exe" | Select-Object -First 1
        if ($exeFile) {
            Copy-Item -Path $exeFile.FullName -Destination "$BIN_DIR\$BINARY_NAME" -Force
            Write-Success "Binary installed: $BIN_DIR\$BINARY_NAME"
        } else {
            Write-Error "Could not find exe in extracted archive"
            exit 1
        }
        
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Error "Failed to download: $_"
        exit 1
    }
} else {
    Write-Step "Building from source..."
    
    # Clone or update repo
    $needsClone = $false
    if (Test-Path $CLONE_DIR) {
        if ($Force -or -not (Test-Path "$CLONE_DIR\go.mod")) {
            Write-Host "    Removing existing clone..."
            Remove-Item -Recurse -Force $CLONE_DIR -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
            
            # Check if removal succeeded
            if (Test-Path $CLONE_DIR) {
                Write-Warning "Could not remove existing clone (directory locked)."
                Write-Warning "Falling back to pre-built binary..."
                $UsePrebuilt = $true
            } else {
                $needsClone = $true
            }
        }
    } else {
        $needsClone = $true
    }
    
    if (-not $UsePrebuilt) {
        if ($needsClone) {
            Write-Host "    Cloning repository..."
            & git clone --depth 1 $REPO_URL $CLONE_DIR
            if ($LASTEXITCODE -ne 0) { Write-Error "Failed to clone repository"; exit 1 }
        }
        
        Write-Host "    Building binary..."
        Push-Location $CLONE_DIR
        & go build -o "$BIN_DIR\$BINARY_NAME" ./cmd/server
        if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Error "Build failed"; exit 1 }
        Pop-Location
        Write-Success "Binary built: $BIN_DIR\$BINARY_NAME"
        
        # Cleanup source directory
        Remove-Item -Recurse -Force $CLONE_DIR -ErrorAction SilentlyContinue
        Write-Success "Source directory cleaned up"
    }
}

# Fallback to prebuilt if source build was skipped
if ($UsePrebuilt -and -not (Test-Path "$BIN_DIR\$BINARY_NAME")) {
    Write-Step "Downloading pre-built binary from GitHub Releases..."
    try {
        $release = Invoke-RestMethod -Uri $RELEASE_API -Headers @{"User-Agent"="PowerShell"}
        $asset = $release.assets | Where-Object { $_.name -like "*windows_amd64.zip" } | Select-Object -First 1
        if (-not $asset) {
            Write-Error "Could not find Windows binary in latest release"
            exit 1
        }
        $zipPath = "$env:TEMP\cliproxyapi.zip"
        $extractPath = "$env:TEMP\cliproxyapi-extract"
        
        Write-Host "    Downloading $($asset.name)..."
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath
        
        if (Test-Path $extractPath) { Remove-Item -Recurse -Force $extractPath }
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        
        $exeFile = Get-ChildItem -Path $extractPath -Recurse -Filter "*.exe" | Select-Object -First 1
        if ($exeFile) {
            Copy-Item -Path $exeFile.FullName -Destination "$BIN_DIR\$BINARY_NAME" -Force
            Write-Success "Binary installed: $BIN_DIR\$BINARY_NAME"
        } else {
            Write-Error "Could not find exe in extracted archive"
            exit 1
        }
        
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Error "Failed to download: $_"
        exit 1
    }
}

# Create config.yaml
Write-Step "Configuring ~/.cliproxyapi/config.yaml..."
$configYaml = @"
port: 8317
auth-dir: "$($CONFIG_DIR -replace '\\', '/')"
api-keys:
  - "sk-dummy"
quota-exceeded:
  switch-project: true
  switch-preview-model: true
incognito-browser: true
request-retry: 3
remote-management:
  allow-remote: false
  secret-key: ""
  disable-control-panel: false
"@

$configPath = "$CONFIG_DIR\config.yaml"
if ((Test-Path $configPath) -and -not $Force) {
    Write-Warning "config.yaml already exists, skipping (use -Force to overwrite)"
} else {
    $configYaml | Out-File -FilePath $configPath -Encoding utf8 -Force
    Write-Success "config.yaml created"
}

# Update .factory/config.json
Write-Step "Updating ~/.factory/config.json..."
$customModels = @{
    custom_models = @(
        @{ model_display_name = "Claude Opus 4.5 Thinking [Antigravity]"; model = "gemini-claude-opus-4-5-thinking"; base_url = "http://localhost:8317/v1"; api_key = "sk-dummy"; provider = "openai" }
        @{ model_display_name = "Claude Sonnet 4.5 Thinking [Antigravity]"; model = "gemini-claude-sonnet-4-5-thinking"; base_url = "http://localhost:8317/v1"; api_key = "sk-dummy"; provider = "openai" }
        @{ model_display_name = "Claude Sonnet 4.5 [Antigravity]"; model = "gemini-claude-sonnet-4-5"; base_url = "http://localhost:8317/v1"; api_key = "sk-dummy"; provider = "openai" }
        @{ model_display_name = "Gemini 3 Pro [Antigravity]"; model = "gemini-3-pro-preview"; base_url = "http://localhost:8317/v1"; api_key = "sk-dummy"; provider = "openai" }
        @{ model_display_name = "GPT OSS 120B [Antigravity]"; model = "gpt-oss-120b-medium"; base_url = "http://localhost:8317/v1"; api_key = "sk-dummy"; provider = "openai" }
        @{ model_display_name = "Claude Opus 4.5 [Copilot]"; model = "claude-opus-4.5"; base_url = "http://localhost:8317/v1"; api_key = "sk-dummy"; provider = "openai" }
        @{ model_display_name = "GPT-5 Mini [Copilot]"; model = "gpt-5-mini"; base_url = "http://localhost:8317/v1"; api_key = "sk-dummy"; provider = "openai" }
        @{ model_display_name = "Grok Code Fast 1 [Copilot]"; model = "grok-code-fast-1"; base_url = "http://localhost:8317/v1"; api_key = "sk-dummy"; provider = "openai" }
        @{ model_display_name = "Gemini 2.5 Pro [Gemini]"; model = "gemini-2.5-pro"; base_url = "http://localhost:8317/v1"; api_key = "sk-dummy"; provider = "openai" }
        @{ model_display_name = "Gemini 3 Pro Preview [Gemini]"; model = "gemini-3-pro-preview"; base_url = "http://localhost:8317/v1"; api_key = "sk-dummy"; provider = "openai" }
        @{ model_display_name = "GPT-5.1 Codex Max [Codex]"; model = "gpt-5.1-codex-max"; base_url = "http://localhost:8317/v1"; api_key = "sk-dummy"; provider = "openai" }
        @{ model_display_name = "Qwen3 Coder Plus [Qwen]"; model = "qwen3-coder-plus"; base_url = "http://localhost:8317/v1"; api_key = "sk-dummy"; provider = "openai" }
        @{ model_display_name = "GLM 4.6 [iFlow]"; model = "glm-4.6"; base_url = "http://localhost:8317/v1"; api_key = "sk-dummy"; provider = "openai" }
        @{ model_display_name = "Minimax M2 [iFlow]"; model = "minimax-m2"; base_url = "http://localhost:8317/v1"; api_key = "sk-dummy"; provider = "openai" }
        @{ model_display_name = "Claude Opus 4.5 [Kiro]"; model = "kiro-claude-opus-4.5"; base_url = "http://localhost:8317/v1"; api_key = "sk-dummy"; provider = "openai" }
        @{ model_display_name = "Claude Sonnet 4.5 [Kiro]"; model = "kiro-claude-sonnet-4.5"; base_url = "http://localhost:8317/v1"; api_key = "sk-dummy"; provider = "openai" }
        @{ model_display_name = "Claude Sonnet 4 [Kiro]"; model = "kiro-claude-sonnet-4"; base_url = "http://localhost:8317/v1"; api_key = "sk-dummy"; provider = "openai" }
        @{ model_display_name = "Claude Haiku 4.5 [Kiro]"; model = "kiro-claude-haiku-4.5"; base_url = "http://localhost:8317/v1"; api_key = "sk-dummy"; provider = "openai" }
    )
}

$factoryConfigPath = "$FACTORY_DIR\config.json"
$customModels | ConvertTo-Json -Depth 10 | Out-File -FilePath $factoryConfigPath -Encoding utf8 -Force
Write-Success "config.json updated with $(($customModels.custom_models).Count) custom models"

# Verify installation
Write-Step "Verifying installation..."
$binaryPath = "$BIN_DIR\$BINARY_NAME"
if (Test-Path $binaryPath) {
    $fileInfo = Get-Item $binaryPath
    if ($fileInfo.Length -gt 1MB) {
        Write-Success "Binary verification passed ($([math]::Round($fileInfo.Length / 1MB, 1)) MB)"
    } else {
        Write-Error "Binary seems corrupted (too small)"
        exit 1
    }
} else {
    Write-Error "Binary not found at $binaryPath"
    exit 1
}

# Add ~/bin to PATH if not already
Write-Step "Configuring PATH..."
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$BIN_DIR*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$BIN_DIR", "User")
    Write-Success "Added $BIN_DIR to PATH"
    $pathAdded = $true
} else {
    Write-Success "$BIN_DIR already in PATH"
    $pathAdded = $false
}

# OAuth login prompts
if (-not $SkipOAuth) {
    Write-Host @"

==============================================
  OAuth Login Setup (Optional)
==============================================
Run these commands to login to each provider:

  # Gemini CLI
  cliproxyapi --config $CONFIG_DIR\config.yaml --login

  # Antigravity
  cliproxyapi --config $CONFIG_DIR\config.yaml --antigravity-login

  # GitHub Copilot
  cliproxyapi --config $CONFIG_DIR\config.yaml --github-copilot-login

  # Codex
  cliproxyapi --config $CONFIG_DIR\config.yaml --codex-login

  # Claude
  cliproxyapi --config $CONFIG_DIR\config.yaml --claude-login

  # Qwen
  cliproxyapi --config $CONFIG_DIR\config.yaml --qwen-login

  # iFlow
  cliproxyapi --config $CONFIG_DIR\config.yaml --iflow-login

  # Kiro (AWS)
  cliproxyapi --config $CONFIG_DIR\config.yaml --kiro-aws-login

==============================================
"@ -ForegroundColor Yellow
}

Write-Host @"

==============================================
  Installation Complete!
==============================================
"@ -ForegroundColor Green

Write-Host @"
Installed Files:
  Binary:   $BIN_DIR\$BINARY_NAME
  Config:   $CONFIG_DIR\config.yaml
  Droid:    $FACTORY_DIR\config.json

Available Scripts (in $BIN_DIR):
  start-cliproxyapi     Start/stop/restart server
  cliproxyapi-oauth     Login to OAuth providers
  gui-cliproxyapi       Open Control Center GUI
  update-cliproxyapi    Update to latest version
  uninstall-cliproxyapi Remove everything

Quick Start:
  1. Start server:    start-cliproxyapi -Background
  2. Login OAuth:     cliproxyapi-oauth -All
  3. Open GUI:        gui-cliproxyapi
  4. Use with Droid:  droid (select cliproxyapi/* model)
"@ -ForegroundColor Cyan

if ($pathAdded) {
    Write-Host @"

NOTE: Restart your terminal for PATH changes to take effect.
      Or run: `$env:Path = [Environment]::GetEnvironmentVariable('Path', 'User')
"@ -ForegroundColor Yellow
}

Write-Host @"
==============================================
"@ -ForegroundColor Green
