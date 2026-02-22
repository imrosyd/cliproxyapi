<#
.SYNOPSIS
    CLIProxyAPI OAuth Login Helper
.DESCRIPTION
    Interactive script to login to all supported OAuth providers.
    Run without parameters for interactive menu, or use flags for specific providers.
.EXAMPLE
    cliproxyapi-oauth.ps1              # Interactive menu
    cliproxyapi-oauth.ps1 -All         # Login to all providers
    cliproxyapi-oauth.ps1 -Gemini      # Login to Gemini only
#>

param(
    [switch]$All,
    [switch]$Gemini,
    [switch]$Antigravity,
    [switch]$Copilot,
    [switch]$Codex,
    [switch]$Claude,
    [switch]$Qwen,
    [switch]$iFlow,
    [switch]$Kiro
)

$CONFIG_DIR = "$env:USERPROFILE\.cliproxyapi"
$CONFIG_FILE = "$CONFIG_DIR\config.yaml"
$BINARY = "$env:USERPROFILE\bin\cliproxyapi.exe"

if (-not (Test-Path $BINARY)) {
    Write-Host "[-] cliproxyapi.exe not found. Run install-cliproxyapi.ps1 first." -ForegroundColor Red
    exit 1
}

$providers = @(
    @{ Name = "Gemini CLI"; Flag = "--login"; Switch = "Gemini" }
    @{ Name = "Antigravity"; Flag = "--antigravity-login"; Switch = "Antigravity" }
    @{ Name = "GitHub Copilot"; Flag = "--github-copilot-login"; Switch = "Copilot" }
    @{ Name = "Codex"; Flag = "--codex-login"; Switch = "Codex" }
    @{ Name = "Claude"; Flag = "--claude-login"; Switch = "Claude" }
    @{ Name = "Qwen"; Flag = "--qwen-login"; Switch = "Qwen" }
    @{ Name = "iFlow"; Flag = "--iflow-login"; Switch = "iFlow" }
    @{ Name = "Kiro (AWS)"; Flag = "--kiro-aws-login"; Switch = "Kiro" }
)

function Invoke-Login {
    param($provider)
    Write-Host "`n[*] Logging in to $($provider.Name)..." -ForegroundColor Cyan
    Write-Host "    Command: cliproxyapi --config $CONFIG_FILE $($provider.Flag)" -ForegroundColor DarkGray
    & $BINARY --config $CONFIG_FILE $provider.Flag
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[+] $($provider.Name) login completed!" -ForegroundColor Green
    }
    else {
        Write-Host "[!] $($provider.Name) login may have issues (exit code: $LASTEXITCODE)" -ForegroundColor Yellow
    }
}

# Check if any specific flag was passed
$anyFlagPassed = $All -or $Gemini -or $Antigravity -or $Copilot -or $Codex -or $Claude -or $Qwen -or $iFlow -or $Kiro

if ($anyFlagPassed) {
    # Direct mode - run specified logins
    Write-Host "=== CLIProxyAPI OAuth Login ===" -ForegroundColor Magenta
    
    foreach ($p in $providers) {
        $switchVar = Get-Variable -Name $p.Switch -ValueOnly -ErrorAction SilentlyContinue
        if ($All -or $switchVar) {
            Invoke-Login $p
        }
    }
}
else {
    # Interactive menu mode
    Write-Host @"
==========================================
  CLIProxyAPI OAuth Login Menu
==========================================
"@ -ForegroundColor Magenta

    Write-Host "Available providers:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $providers.Count; $i++) {
        Write-Host "  $($i + 1). $($providers[$i].Name)"
    }
    Write-Host "  A. Login to ALL providers"
    Write-Host "  Q. Quit"
    Write-Host ""

    while ($true) {
        $choice = Read-Host "Select provider(s) [1-8, A, or Q]"
        
        if ($choice -eq 'Q' -or $choice -eq 'q') {
            Write-Host "Bye!" -ForegroundColor Green
            break
        }
        
        if ($choice -eq 'A' -or $choice -eq 'a') {
            Write-Host "`nLogging in to ALL providers..." -ForegroundColor Yellow
            foreach ($p in $providers) {
                Invoke-Login $p
                Write-Host "`nPress Enter to continue to next provider..." -ForegroundColor DarkGray
                Read-Host
            }
            Write-Host "`n[+] All logins completed!" -ForegroundColor Green
            break
        }
        
        # Handle comma-separated numbers like "1,2,3"
        $selections = $choice -split ',' | ForEach-Object { $_.Trim() }
        
        foreach ($sel in $selections) {
            if ($sel -match '^\d+$') {
                $idx = [int]$sel - 1
                if ($idx -ge 0 -and $idx -lt $providers.Count) {
                    Invoke-Login $providers[$idx]
                }
                else {
                    Write-Host "[!] Invalid selection: $sel" -ForegroundColor Yellow
                }
            }
        }
        
        Write-Host ""
    }
}

Write-Host @"

==========================================
  Auth files saved in: $CONFIG_DIR
==========================================
"@ -ForegroundColor Green
