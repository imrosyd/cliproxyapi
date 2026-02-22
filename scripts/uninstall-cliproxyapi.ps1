<#
.SYNOPSIS
    CLIProxyAPI Uninstaller
.DESCRIPTION
    Completely removes CLIProxyAPI and all related files.
    By default, preserves auth files and .factory/config.json.
.EXAMPLE
    uninstall-cliproxyapi.ps1              # Interactive, keeps auth
    uninstall-cliproxyapi.ps1 -All         # Remove everything
    uninstall-cliproxyapi.ps1 -KeepAuth    # Keep OAuth tokens
    uninstall-cliproxyapi.ps1 -Force       # No confirmation
#>

param(
    [switch]$All,
    [switch]$KeepAuth,
    [switch]$KeepDroidConfig,
    [switch]$Force
)

$ErrorActionPreference = "SilentlyContinue"

$BIN_DIR = "$env:USERPROFILE\bin"
$CONFIG_DIR = "$env:USERPROFILE\.cliproxyapi"
$CLONE_DIR = "$env:USERPROFILE\CLIProxyAPI-source"
$FACTORY_CONFIG = "$env:USERPROFILE\.factory\config.json"

$items = @(
    @{ Name = "Binary"; Path = "$BIN_DIR\cliproxyapi.exe"; Type = "File"; Always = $true }
    @{ Name = "Binary backup"; Path = "$BIN_DIR\cliproxyapi.exe.old"; Type = "File"; Always = $true }
    @{ Name = "Install script"; Path = "$BIN_DIR\install-cliproxyapi.ps1"; Type = "File"; Always = $true }
    @{ Name = "Update script"; Path = "$BIN_DIR\update-cliproxyapi.ps1"; Type = "File"; Always = $true }
    @{ Name = "OAuth script"; Path = "$BIN_DIR\cliproxyapi-oauth.ps1"; Type = "File"; Always = $true }
    @{ Name = "Uninstall script"; Path = "$BIN_DIR\uninstall-cliproxyapi.ps1"; Type = "File"; Always = $true }
    @{ Name = "Clone directory"; Path = $CLONE_DIR; Type = "Directory"; Always = $true }
    @{ Name = "Config (config.yaml)"; Path = "$CONFIG_DIR\config.yaml"; Type = "File"; Always = $true }
    @{ Name = "Logs directory"; Path = "$CONFIG_DIR\logs"; Type = "Directory"; Always = $true }
    @{ Name = "Scripts directory"; Path = "$CONFIG_DIR\scripts"; Type = "Directory"; Always = $true }
    @{ Name = "Static directory"; Path = "$CONFIG_DIR\static"; Type = "Directory"; Always = $true }
    @{ Name = "Auth files (*.json)"; Path = "$CONFIG_DIR\*.json"; Type = "Glob"; Always = $false; KeepFlag = "KeepAuth" }
    @{ Name = "Config directory"; Path = $CONFIG_DIR; Type = "Directory"; Always = $false; KeepFlag = "KeepAuth" }
    @{ Name = "Droid config"; Path = $FACTORY_CONFIG; Type = "ConfigJson"; Always = $false; KeepFlag = "KeepDroidConfig" }
)

function Get-Size {
    param($path, $type)
    if ($type -eq "Directory" -and (Test-Path $path)) {
        $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        return "{0:N2} MB" -f ($size / 1MB)
    } elseif ($type -eq "File" -and (Test-Path $path)) {
        $size = (Get-Item $path).Length
        return "{0:N2} KB" -f ($size / 1KB)
    } elseif ($type -eq "Glob") {
        $files = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
        return "$($files.Count) files"
    }
    return "N/A"
}

Write-Host @"
==========================================
  CLIProxyAPI Uninstaller
==========================================
"@ -ForegroundColor Red

# Determine what to remove
$removeAuth = $All -and -not $KeepAuth
$removeDroidConfig = $All -and -not $KeepDroidConfig

Write-Host "`n[*] Scanning installation..." -ForegroundColor Cyan

$toRemove = @()
$toKeep = @()

foreach ($item in $items) {
    $exists = $false
    if ($item.Type -eq "Glob") {
        $exists = (Get-ChildItem -Path $item.Path -ErrorAction SilentlyContinue).Count -gt 0
    } elseif ($item.Type -eq "ConfigJson") {
        $exists = Test-Path $item.Path
    } else {
        $exists = Test-Path $item.Path
    }
    
    if (-not $exists) { continue }
    
    $size = Get-Size $item.Path $item.Type
    $itemInfo = @{ Name = $item.Name; Path = $item.Path; Type = $item.Type; Size = $size }
    
    if ($item.Always) {
        $toRemove += $itemInfo
    } elseif ($item.KeepFlag -eq "KeepAuth" -and -not $removeAuth) {
        $toKeep += $itemInfo
    } elseif ($item.KeepFlag -eq "KeepDroidConfig" -and -not $removeDroidConfig) {
        $toKeep += $itemInfo
    } else {
        $toRemove += $itemInfo
    }
}

# Display what will be removed
if ($toRemove.Count -eq 0) {
    Write-Host "`n[!] Nothing to remove. CLIProxyAPI is not installed." -ForegroundColor Yellow
    exit 0
}

Write-Host "`n[!] The following items will be REMOVED:" -ForegroundColor Red
foreach ($item in $toRemove) {
    Write-Host "    - $($item.Name) ($($item.Size))" -ForegroundColor White
    Write-Host "      $($item.Path)" -ForegroundColor DarkGray
}

if ($toKeep.Count -gt 0) {
    Write-Host "`n[*] The following items will be KEPT:" -ForegroundColor Green
    foreach ($item in $toKeep) {
        Write-Host "    - $($item.Name) ($($item.Size))" -ForegroundColor White
        Write-Host "      $($item.Path)" -ForegroundColor DarkGray
    }
    Write-Host "`n    Use -All to remove everything" -ForegroundColor DarkGray
}

# Confirmation
if (-not $Force) {
    Write-Host ""
    $confirm = Read-Host "Are you sure you want to uninstall? [y/N]"
    if ($confirm -notmatch '^[Yy]') {
        Write-Host "`n[*] Uninstall cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Remove items
Write-Host "`n[*] Removing CLIProxyAPI..." -ForegroundColor Cyan
$removed = @()
$failed = @()

foreach ($item in $toRemove) {
    try {
        if ($item.Type -eq "File") {
            Remove-Item -Path $item.Path -Force -ErrorAction Stop
            $removed += $item.Name
        } elseif ($item.Type -eq "Directory") {
            Remove-Item -Path $item.Path -Recurse -Force -ErrorAction Stop
            $removed += $item.Name
        } elseif ($item.Type -eq "Glob") {
            Remove-Item -Path $item.Path -Force -ErrorAction Stop
            $removed += $item.Name
        } elseif ($item.Type -eq "ConfigJson") {
            # Clear custom_models from .factory/config.json instead of deleting
            if (Test-Path $item.Path) {
                $json = Get-Content $item.Path -Raw | ConvertFrom-Json
                $json.custom_models = @()
                $json | ConvertTo-Json -Depth 10 | Out-File $item.Path -Encoding utf8
                $removed += "$($item.Name) (cleared custom_models)"
            }
        }
        Write-Host "    [+] Removed: $($item.Name)" -ForegroundColor Green
    } catch {
        $failed += @{ Name = $item.Name; Error = $_.Exception.Message }
        Write-Host "    [-] Failed: $($item.Name) - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Clean up empty config directory
if ((Test-Path $CONFIG_DIR) -and $removeAuth) {
    $remaining = Get-ChildItem -Path $CONFIG_DIR -Force -ErrorAction SilentlyContinue
    if ($remaining.Count -eq 0) {
        Remove-Item -Path $CONFIG_DIR -Force -ErrorAction SilentlyContinue
        Write-Host "    [+] Removed: Empty config directory" -ForegroundColor Green
    }
}

# Summary
Write-Host @"

==========================================
  Uninstall Complete!
==========================================
"@ -ForegroundColor Green

Write-Host "Removed: $($removed.Count) items" -ForegroundColor White
if ($failed.Count -gt 0) {
    Write-Host "Failed:  $($failed.Count) items" -ForegroundColor Red
}
if ($toKeep.Count -gt 0) {
    Write-Host "Kept:    $($toKeep.Count) items" -ForegroundColor Yellow
}

if ($toKeep.Count -gt 0 -and -not $All) {
    Write-Host "`nTo remove everything including auth files:" -ForegroundColor DarkGray
    Write-Host "  uninstall-cliproxyapi.ps1 -All -Force" -ForegroundColor DarkGray
}

Write-Host ""
