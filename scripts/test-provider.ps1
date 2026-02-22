<#
.SYNOPSIS
    Test connection to a custom AI provider

.DESCRIPTION
    Test if the provider's API endpoint is reachable and the credentials are valid.

.PARAMETER Name
    Provider name to test

.PARAMETER BaseUrl
    Custom base URL to test (overrides provider config)

.PARAMETER ApiKey
    Custom API key to test (overrides provider config)

.EXAMPLE
    .\test-provider.ps1 -Name openrouter

.EXAMPLE
    .\test-provider.ps1 -BaseUrl https://api.example.com/v1 -ApiKey sk-xxx
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Name,
    
    [string]$BaseUrl,
    [string]$ApiKey,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

$ProvidersPath = "$env:USERPROFILE\.cliproxyapi\providers.json"

if ($Name) {
    if (-not (Test-Path $ProvidersPath)) {
        Write-Host "No providers configured." -ForegroundColor Red
        exit 1
    }
    
    $content = Get-Content $ProvidersPath -Raw | ConvertFrom-Json
    $provider = $content.providers.PSObject.Properties[$Name]
    
    if (-not $provider) {
        Write-Host "Provider '$Name' not found." -ForegroundColor Red
        exit 1
    }
    
    $p = $provider.Value
    $BaseUrl = if ($BaseUrl) { $BaseUrl } else { $p.options.baseURL }
    $ApiKey = if ($ApiKey) { $ApiKey } else { $p.options.apiKey }
}

if (-not $BaseUrl) {
    Write-Host "Base URL is required. Use -Name or -BaseUrl parameter." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Testing provider connection..." -ForegroundColor Cyan
Write-Host "  Base URL: $BaseUrl" -ForegroundColor White
if ($Name) { Write-Host "  Provider: $Name" -ForegroundColor White }
Write-Host ""

try {
    $headers = @{
        "Content-Type" = "application/json"
    }
    
    if ($ApiKey) {
        $headers["Authorization"] = "Bearer $ApiKey"
    }
    
    $testUrl = $BaseUrl.TrimEnd('/') + '/models'
    
    Write-Host "  Connecting..." -ForegroundColor Yellow -NoNewline
    
    $response = Invoke-WebRequest -Uri $testUrl -Method Get -Headers $headers -TimeoutSec 30 -UseBasicParsing
    
    if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
        Write-Host " ✓ Connected!" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Status: $($response.StatusCode)" -ForegroundColor Green
        
        try {
            $data = $response.Content | ConvertFrom-Json
            if ($data.data) {
                $modelCount = $data.data.Count
                Write-Host "  Models available: $modelCount" -ForegroundColor White
                
                if ($modelCount -gt 0) {
                    Write-Host ""
                    Write-Host "  Sample models:" -ForegroundColor Cyan
                    $data.data | Select-Object -First 5 | ForEach-Object {
                        $modelId = if ($_.id) { $_.id } else { $_ }
                        Write-Host "    • $modelId" -ForegroundColor White
                    }
                    if ($modelCount -gt 5) {
                        Write-Host "    ... and $($modelCount - 5) more" -ForegroundColor DarkGray
                    }
                }
            }
        } catch {
            Write-Host "  Response received but could not parse models list" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "  ✅ Connection test PASSED" -ForegroundColor Green
    } else {
        Write-Host " ✗ Failed" -ForegroundColor Red
        Write-Host "  Status: $($response.StatusCode)" -ForegroundColor Red
    }
} catch {
    Write-Host " ✗ Failed" -ForegroundColor Red
    Write-Host ""
    
    $errorMsg = $_.Exception.Message
    
    if ($errorMsg -match "Unable to connect|No such host|network") {
        Write-Host "  Error: Cannot reach the server" -ForegroundColor Red
        Write-Host "  " -NoNewline
        Write-Host "→ Check if the Base URL is correct and the server is running" -ForegroundColor Yellow
    } elseif ($errorMsg -match "401|Unauthorized|authentication") {
        Write-Host "  Error: Authentication failed (401 Unauthorized)" -ForegroundColor Red
        Write-Host "  " -NoNewline
        Write-Host "→ Check if your API key is correct" -ForegroundColor Yellow
    } elseif ($errorMsg -match "403|Forbidden") {
        Write-Host "  Error: Access forbidden (403)" -ForegroundColor Red
        Write-Host "  " -NoNewline
        Write-Host "→ Check your API key permissions" -ForegroundColor Yellow
    } elseif ($errorMsg -match "timeout|timed out") {
        Write-Host "  Error: Connection timed out" -ForegroundColor Red
        Write-Host "  " -NoNewline
        Write-Host "→ Server may be slow or unreachable" -ForegroundColor Yellow
    } else {
        Write-Host "  Error: $errorMsg" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "  ❌ Connection test FAILED" -ForegroundColor Red
    exit 1
}

Write-Host ""
