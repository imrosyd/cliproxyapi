<#
.SYNOPSIS
    CLIProxyAPI Update Script
.DESCRIPTION
    Updates CLIProxyAPI to the latest version.
    - Pulls latest from repo OR downloads latest release
    - Rebuilds binary OR extracts pre-built
    - Preserves all config and auth files
.NOTES
    Author: Auto-generated for faiz
    Repo: https://github.com/imrosyd/cliproxyapi
#>

param(
    [switch]$UsePrebuilt,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$REPO_URL = "https://github.com/imrosyd/cliproxyapi.git"
$RELEASE_API = "https://api.github.com/repos/imrosyd/cliproxyapi/releases/latest"
$CLONE_DIR = "$env:USERPROFILE\CLIProxyAPI"
$BIN_DIR = "$env:USERPROFILE\bin"
$CONFIG_DIR = "$env:USERPROFILE\.cliproxyapi"
$BINARY_NAME = "cliproxyapi.exe"

function Write-Step { param($msg) Write-Host "`n[*] $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "[+] $msg" -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "[-] $msg" -ForegroundColor Red }

Write-Host @"
==============================================
  CLIProxyAPI Updater
==============================================
"@ -ForegroundColor Magenta

# Check current version
Write-Step "Checking current installation..."
$binaryPath = "$BIN_DIR\$BINARY_NAME"
if (Test-Path $binaryPath) {
    $fileInfo = Get-Item $binaryPath
    Write-Host "    Current binary: $($fileInfo.LastWriteTime)"
} else {
    Write-Warning "Binary not found. Run install-cliproxyapi.ps1 first."
    exit 1
}

# Check for latest release
Write-Step "Fetching latest release info..."
try {
    $release = Invoke-RestMethod -Uri $RELEASE_API -Headers @{"User-Agent"="PowerShell"}
    Write-Host "    Latest version: $($release.tag_name)"
    Write-Host "    Published: $($release.published_at)"
} catch {
    Write-Warning "Could not fetch release info: $_"
}

# Determine update method
if (-not $UsePrebuilt -and (Test-Path $CLONE_DIR)) {
    Write-Step "Updating from source..."
    
    Push-Location $CLONE_DIR
    
    # Fetch and check for updates
    Write-Host "    Fetching latest changes..."
    & git fetch origin main
    
    $localHash = & git rev-parse HEAD
    $remoteHash = & git rev-parse origin/main
    
    if ($localHash -eq $remoteHash -and -not $Force) {
        Write-Success "Already up to date!"
        Pop-Location
        exit 0
    }
    
    Write-Host "    Pulling latest changes..."
    & git pull origin main --rebase
    if ($LASTEXITCODE -ne 0) { 
        Write-Warning "Git pull failed, trying reset..."
        & git fetch origin main
        & git reset --hard origin/main
    }
    
    Write-Host "    Building binary..."
    & go build -o "$BIN_DIR\$BINARY_NAME" ./cmd/server
    if ($LASTEXITCODE -ne 0) { 
        Pop-Location
        Write-Error "Build failed"
        exit 1 
    }
    
    Pop-Location
    Write-Success "Binary rebuilt from source"
    
} else {
    Write-Step "Downloading latest pre-built binary..."
    
    try {
        $release = Invoke-RestMethod -Uri $RELEASE_API -Headers @{"User-Agent"="PowerShell"}
        $asset = $release.assets | Where-Object { $_.name -like "*windows_amd64.zip" } | Select-Object -First 1
        
        if (-not $asset) {
            Write-Error "Could not find Windows binary in latest release"
            exit 1
        }
        
        $zipPath = "$env:TEMP\cliproxyapi-update.zip"
        $extractPath = "$env:TEMP\cliproxyapi-extract"
        
        Write-Host "    Downloading $($asset.name)..."
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath
        
        if (Test-Path $extractPath) { Remove-Item -Recurse -Force $extractPath }
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        
        $exeFile = Get-ChildItem -Path $extractPath -Recurse -Filter "*.exe" | Select-Object -First 1
        if ($exeFile) {
            # Backup old binary
            $backupPath = "$BIN_DIR\$BINARY_NAME.old"
            if (Test-Path $binaryPath) {
                Copy-Item -Path $binaryPath -Destination $backupPath -Force
            }
            
            Copy-Item -Path $exeFile.FullName -Destination $binaryPath -Force
            Write-Success "Binary updated: $binaryPath"
            Write-Host "    Backup saved: $backupPath"
        } else {
            Write-Error "Could not find exe in extracted archive"
            exit 1
        }
        
        # Cleanup
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        
    } catch {
        Write-Error "Failed to download: $_"
        exit 1
    }
}

# Verify update
Write-Step "Verifying update..."
if (Test-Path $binaryPath) {
    $newFileInfo = Get-Item $binaryPath
    Write-Success "Update complete!"
    Write-Host "    Binary updated: $($newFileInfo.LastWriteTime)"
} else {
    Write-Error "Binary verification failed"
    exit 1
}

Write-Host @"

==============================================
  Update Complete!
==============================================
Binary:  $binaryPath
Config:  $CONFIG_DIR\config.yaml (preserved)
Auth:    $CONFIG_DIR\*.json (preserved)

To start the server:
  cliproxyapi --config $CONFIG_DIR\config.yaml
==============================================
"@ -ForegroundColor Green
