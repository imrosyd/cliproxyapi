<#
.SYNOPSIS
    CLIProxyAPI-Plus GUI Launcher
.DESCRIPTION
    Opens the Control Center GUI in your default browser.
.EXAMPLE
    gui-cliproxyapi.ps1
#>

$GUI_PATH = "$PSScriptRoot\..\gui\index.html"

# Check if GUI exists
if (-not (Test-Path $GUI_PATH)) {
    # Try alternate location
    $GUI_PATH = "$env:USERPROFILE\CLIProxyAPIPlus-Easy-Installation\gui\index.html"
}

if (-not (Test-Path $GUI_PATH)) {
    Write-Host "[-] GUI not found. Please reinstall." -ForegroundColor Red
    exit 1
}

Write-Host "[*] Opening CLIProxyAPI+ Control Center..." -ForegroundColor Cyan
Start-Process $GUI_PATH

Write-Host "[+] GUI opened in browser" -ForegroundColor Green
Write-Host ""
Write-Host "Note: The GUI monitors server status but requires PowerShell" -ForegroundColor Yellow
Write-Host "      commands to start/stop the server." -ForegroundColor Yellow
Write-Host ""
Write-Host "Quick commands:" -ForegroundColor Cyan
Write-Host "  start-cliproxyapi.ps1 -Background  # Start server"
Write-Host "  start-cliproxyapi.ps1 -Stop        # Stop server"
Write-Host "  start-cliproxyapi.ps1 -Status      # Check status"
