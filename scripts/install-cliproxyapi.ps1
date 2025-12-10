<#
.SYNOPSIS
    CLIProxyAPI-Plus Installation Script for Droid CLI
.DESCRIPTION
    Complete one-click installer that sets up CLIProxyAPI-Plus for Factory Droid.
    - Clones or downloads pre-built binary
    - Configures ~/.cli-proxy-api/config.yaml
    - Updates ~/.factory/config.json with custom models
    - Provides OAuth login prompts
.NOTES
    Author: Auto-generated for faiz
    Repo: https://github.com/router-for-me/CLIProxyAPIPlus
#>

param(
    [switch]$UsePrebuilt,
    [switch]$SkipOAuth,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$REPO_URL = "https://github.com/router-for-me/CLIProxyAPIPlus.git"
$RELEASE_API = "https://api.github.com/repos/router-for-me/CLIProxyAPIPlus/releases/latest"
$CLONE_DIR = "$env:USERPROFILE\CLIProxyAPIPlus"
$BIN_DIR = "$env:USERPROFILE\bin"
$CONFIG_DIR = "$env:USERPROFILE\.cli-proxy-api"
$FACTORY_DIR = "$env:USERPROFILE\.factory"
$BINARY_NAME = "cliproxyapi-plus.exe"

function Write-Step { param($msg) Write-Host "`n[*] $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "[+] $msg" -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "[-] $msg" -ForegroundColor Red }

Write-Host @"
==============================================
  CLIProxyAPI-Plus Installer for Droid CLI
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
        $zipPath = "$env:TEMP\cliproxyapi-plus.zip"
        $extractPath = "$env:TEMP\cliproxyapi-plus-extract"
        
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
    if (Test-Path $CLONE_DIR) {
        if ($Force) {
            Write-Host "    Removing existing clone..."
            Remove-Item -Recurse -Force $CLONE_DIR -ErrorAction SilentlyContinue
        } elseif (-not (Test-Path "$CLONE_DIR\go.mod")) {
            Write-Host "    Existing clone is invalid, removing..."
            Remove-Item -Recurse -Force $CLONE_DIR -ErrorAction SilentlyContinue
        }
    }
    
    if (-not (Test-Path $CLONE_DIR)) {
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
}

# Create config.yaml
Write-Step "Configuring ~/.cli-proxy-api/config.yaml..."
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

# OAuth login prompts
if (-not $SkipOAuth) {
    Write-Host @"

==============================================
  OAuth Login Setup (Optional)
==============================================
Run these commands to login to each provider:

  # Gemini CLI
  cliproxyapi-plus --config $CONFIG_DIR\config.yaml --login

  # Antigravity
  cliproxyapi-plus --config $CONFIG_DIR\config.yaml --antigravity-login

  # GitHub Copilot
  cliproxyapi-plus --config $CONFIG_DIR\config.yaml --github-copilot-login

  # Codex
  cliproxyapi-plus --config $CONFIG_DIR\config.yaml --codex-login

  # Claude
  cliproxyapi-plus --config $CONFIG_DIR\config.yaml --claude-login

  # Qwen
  cliproxyapi-plus --config $CONFIG_DIR\config.yaml --qwen-login

  # iFlow
  cliproxyapi-plus --config $CONFIG_DIR\config.yaml --iflow-login

  # Kiro (AWS)
  cliproxyapi-plus --config $CONFIG_DIR\config.yaml --kiro-aws-login

==============================================
"@ -ForegroundColor Yellow
}

Write-Host @"

==============================================
  Installation Complete!
==============================================
Binary:     $BIN_DIR\$BINARY_NAME
Config:     $CONFIG_DIR\config.yaml
Droid:      $FACTORY_DIR\config.json

To start the server:
  cliproxyapi-plus --config $CONFIG_DIR\config.yaml

To update later:
  update-cliproxyapi.ps1
==============================================
"@ -ForegroundColor Green
