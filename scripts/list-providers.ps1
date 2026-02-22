<#
.SYNOPSIS
    List all custom AI providers for CLIProxyAPI

.DESCRIPTION
    Display all configured custom providers with their models and settings.

.PARAMETER Format
    Output format: table (default), json, or yaml

.PARAMETER Name
    Show details for a specific provider

.EXAMPLE
    .\list-providers.ps1

.EXAMPLE
    .\list-providers.ps1 -Format json

.EXAMPLE
    .\list-providers.ps1 -Name openrouter
#>

param(
    [ValidateSet("table", "json", "yaml")]
    [string]$Format = "table",
    [string]$Name,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

$ProvidersPath = "$env:USERPROFILE\.cliproxyapi\providers.json"

if (-not (Test-Path $ProvidersPath)) {
    Write-Host "No providers configured yet." -ForegroundColor Yellow
    Write-Host "Run 'add-provider.ps1' to add a provider." -ForegroundColor Cyan
    exit 0
}

$content = Get-Content $ProvidersPath -Raw | ConvertFrom-Json
$providers = $content.providers

if (-not $providers -or $providers.PSObject.Properties.Count -eq 0) {
    Write-Host "No providers configured." -ForegroundColor Yellow
    exit 0
}

if ($Name) {
    $provider = $providers.PSObject.Properties[$Name]
    if (-not $provider) {
        Write-Host "Provider '$Name' not found." -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    Write-Host "Provider: $Name" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor DarkGray
    
    $p = $provider.Value
    
    if ($p.npm) {
        Write-Host "NPM Package:  $($p.npm)" -ForegroundColor White
    }
    Write-Host "Base URL:     $($p.options.baseURL)" -ForegroundColor White
    if ($p.options.apiKey) {
        $maskedKey = $p.options.apiKey.Substring(0, [Math]::Min(8, $p.options.apiKey.Length)) + "..."
        Write-Host "API Key:      $maskedKey" -ForegroundColor White
    }
    
    if ($p.options.headers) {
        Write-Host "Headers:" -ForegroundColor Yellow
        $p.options.headers.PSObject.Properties | ForEach-Object {
            Write-Host "  $($_.Name): $($_.Value)" -ForegroundColor White
        }
    }
    
    if ($p.models) {
        Write-Host ""
        Write-Host "Models ($($p.models.PSObject.Properties.Count)):" -ForegroundColor Yellow
        Write-Host ""
        
        $p.models.PSObject.Properties | ForEach-Object {
            $m = $_.Value
            $modelId = $_.Name
            $displayName = if ($m.name) { $m.name } else { $modelId }
            
            Write-Host "  • $displayName" -ForegroundColor White
            Write-Host "    ID: $modelId" -ForegroundColor DarkGray
            
            if ($m.limit) {
                $limits = @()
                if ($m.limit.context) { $limits += "Context: $($m.limit.context)" }
                if ($m.limit.output) { $limits += "Output: $($m.limit.output)" }
                Write-Host "    Limits: $($limits -join ', ') tokens" -ForegroundColor DarkGray
            }
            
            if ($m.reasoning) {
                Write-Host "    Reasoning: Yes" -ForegroundColor DarkGray
            }
            
            if ($m.modalities) {
                $input = $m.modalities.input -join ', '
                $output = $m.modalities.output -join ', '
                Write-Host "    Modalities: Input [$input] → Output [$output]" -ForegroundColor DarkGray
            }
            
            Write-Host ""
        }
    }
    
    exit 0
}

switch ($Format) {
    "json" {
        $providers | ConvertTo-Json -Depth 10
    }
    
    "yaml" {
        Write-Host "# CLIProxyAPI Providers"
        $providers.PSObject.Properties | ForEach-Object {
            $name = $_.Name
            $p = $_.Value
            
            Write-Host ""
            Write-Host "$name:"
            if ($p.npm) { Write-Host "  npm: $($p.npm)" }
            Write-Host "  options:"
            Write-Host "    baseURL: $($p.options.baseURL)"
            if ($p.options.apiKey) { Write-Host "    apiKey: $($p.options.apiKey)" }
            
            if ($p.models) {
                Write-Host "  models:"
                $p.models.PSObject.Properties | ForEach-Object {
                    $modelId = $_.Name
                    $m = $_.Value
                    Write-Host "    $modelId:"
                    if ($m.name) { Write-Host "      name: $($m.name)" }
                    if ($m.reasoning) { Write-Host "      reasoning: true" }
                    if ($m.limit) {
                        Write-Host "      limit:"
                        if ($m.limit.context) { Write-Host "        context: $($m.limit.context)" }
                        if ($m.limit.output) { Write-Host "        output: $($m.limit.output)" }
                    }
                }
            }
        }
    }
    
    default {
        Write-Host ""
        Write-Host "  ╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "  ║               CLIProxyAPI - Custom Providers                  ║" -ForegroundColor Cyan
        Write-Host "  ╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        
        $providers.PSObject.Properties | ForEach-Object {
            $name = $_.Name
            $p = $_.Value
            $modelCount = if ($p.models) { $p.models.PSObject.Properties.Count } else { 0 }
            
            Write-Host "  ┌─────────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
            Write-Host "  │ " -NoNewline -ForegroundColor DarkGray
            Write-Host "$name".PadRight(20) -NoNewline -ForegroundColor Cyan
            Write-Host " " -NoNewline
            if ($p.npm) {
                Write-Host "[$($p.npm)]".PadRight(35) -NoNewline -ForegroundColor DarkGray
            } else {
                Write-Host "".PadRight(35) -NoNewline
            }
            Write-Host " │" -ForegroundColor DarkGray
            Write-Host "  │ " -NoNewline -ForegroundColor DarkGray
            Write-Host "$($p.options.baseURL)".PadRight(59) -NoNewline -ForegroundColor White
            Write-Host " │" -ForegroundColor DarkGray
            Write-Host "  │ " -NoNewline -ForegroundColor DarkGray
            Write-Host "$modelCount model$(if ($modelCount -ne 1) { 's' })".PadRight(59) -NoNewline -ForegroundColor DarkGray
            Write-Host " │" -ForegroundColor DarkGray
            Write-Host "  └─────────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
            Write-Host ""
        }
        
        Write-Host "  Total: $($providers.PSObject.Properties.Count) provider(s)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Run 'list-providers.ps1 -Name <provider>' for details" -ForegroundColor DarkGray
        Write-Host ""
    }
}
