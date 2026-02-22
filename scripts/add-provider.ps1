<#
.SYNOPSIS
    Add or edit a custom AI provider for CLIProxyAPI

.DESCRIPTION
    Interactive wizard to add custom AI providers compatible with AI SDK format.
    Providers are saved to ~/.cliproxyapi/providers.json

.PARAMETER Name
    Provider name (e.g., openrouter, ollama)

.PARAMETER BaseUrl
    API base URL (e.g., https://openrouter.ai/api/v1)

.PARAMETER ApiKey
    API key for authentication

.PARAMETER Npm
    NPM package name for the SDK

.PARAMETER Template
    Use a pre-defined template (openrouter, ollama, lmstudio, together, groq, deepseek)

.EXAMPLE
    .\add-provider.ps1 -Template openrouter -ApiKey sk-or-xxx

.EXAMPLE
    .\add-provider.ps1 -Name "my-provider" -BaseUrl "https://api.example.com/v1" -ApiKey "xxx"
#>

param(
    [string]$Name,
    [string]$BaseUrl,
    [string]$ApiKey,
    [string]$Npm,
    [string]$Template,
    [switch]$Interactive,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

$ProvidersPath = "$env:USERPROFILE\.cliproxyapi\providers.json"
$ProvidersDir = Split-Path $ProvidersPath -Parent

function Show-Banner {
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║     CLIProxyAPI - Add Custom Provider             ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Get-Templates {
    return @{
        "openrouter" = @{
            Name = "openrouter"
            Npm = ""
            BaseUrl = "https://openrouter.ai/api/v1"
            Description = "Access 100+ models via OpenRouter"
        }
        "ollama" = @{
            Name = "ollama"
            Npm = ""
            BaseUrl = "http://localhost:11434/v1"
            Description = "Local LLM via Ollama"
        }
        "lmstudio" = @{
            Name = "lmstudio"
            Npm = ""
            BaseUrl = "http://localhost:1234/v1"
            Description = "Local LLM via LM Studio"
        }
        "together" = @{
            Name = "together"
            Npm = "@together-ai/sdk"
            BaseUrl = "https://api.together.xyz/v1"
            Description = "Together AI cloud API"
        }
        "groq" = @{
            Name = "groq"
            Npm = "groq-sdk"
            BaseUrl = "https://api.groq.com/openai/v1"
            Description = "Groq fast inference"
        }
        "deepseek" = @{
            Name = "deepseek"
            Npm = ""
            BaseUrl = "https://api.deepseek.com/v1"
            ApiKey = ""
            Description = "DeepSeek API"
        }
    }
}

function Load-Providers {
    if (Test-Path $ProvidersPath) {
        $content = Get-Content $ProvidersPath -Raw | ConvertFrom-Json
        return $content.providers
    }
    return @{}
}

function Save-Providers($providers) {
    if (-not (Test-Path $ProvidersDir)) {
        New-Item -ItemType Directory -Path $ProvidersDir -Force | Out-Null
    }
    
    $data = @{
        '$schema' = "https://cliproxyapi.dev/schema/providers.json"
        providers = $providers
    }
    
    $data | ConvertTo-Json -Depth 10 | Set-Content $ProvidersPath -Encoding UTF8
    Write-Host "✓ Saved to $ProvidersPath" -ForegroundColor Green
}

function Add-Provider($name, $provider) {
    $providers = Load-Providers
    
    if ($providers.PSObject.Properties[$name]) {
        Write-Host "⚠ Provider '$name' already exists. Updating..." -ForegroundColor Yellow
    }
    
    $providers | Add-Member -MemberType NoteProperty -Name $name -Value $provider -Force
    Save-Providers $providers
    
    Write-Host ""
    Write-Host "✓ Provider '$name' added successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Provider configuration:" -ForegroundColor Cyan
    Write-Host "  Name:      $name" -ForegroundColor White
    Write-Host "  Base URL:  $($provider.options.baseURL)" -ForegroundColor White
    if ($provider.npm) { Write-Host "  NPM:       $($provider.npm)" -ForegroundColor White }
    Write-Host ""
}

function Interactive-Wizard {
    Show-Banner
    
    $templates = Get-Templates
    
    Write-Host "Select an option:" -ForegroundColor Yellow
    Write-Host "  1. Use a template"
    Write-Host "  2. Add custom provider"
    Write-Host ""
    
    $choice = Read-Host "Choice [1-2]"
    
    if ($choice -eq "1") {
        Write-Host ""
        Write-Host "Available templates:" -ForegroundColor Yellow
        $templateList = @($templates.Keys)
        for ($i = 0; $i -lt $templateList.Count; $i++) {
            $t = $templates[$templateList[$i]]
            Write-Host "  $($i + 1). $($t.Name.PadRight(15)) - $($t.Description)" -ForegroundColor White
        }
        Write-Host ""
        
        $templateChoice = Read-Host "Select template [1-$($templateList.Count)]"
        $templateIndex = [int]$templateChoice - 1
        
        if ($templateIndex -ge 0 -and $templateIndex -lt $templateList.Count) {
            $selectedTemplate = $templates[$templateList[$templateIndex]]
            $Name = $selectedTemplate.Name
            $BaseUrl = $selectedTemplate.BaseUrl
            $Npm = $selectedTemplate.Npm
            $ApiKey = $selectedTemplate.ApiKey
            
            Write-Host ""
            Write-Host "Template: $($selectedTemplate.Name)" -ForegroundColor Cyan
            Write-Host "Base URL: $BaseUrl" -ForegroundColor White
            Write-Host ""
        } else {
            Write-Host "Invalid selection" -ForegroundColor Red
            exit 1
        }
    }
    
    if (-not $Name) {
        $Name = Read-Host "Provider name (e.g., openrouter)"
        if (-not $Name) {
            Write-Host "Provider name is required" -ForegroundColor Red
            exit 1
        }
    }
    
    if (-not $BaseUrl) {
        $BaseUrl = Read-Host "Base URL (e.g., https://openrouter.ai/api/v1)"
        if (-not $BaseUrl) {
            Write-Host "Base URL is required" -ForegroundColor Red
            exit 1
        }
    }
    
    if (-not $ApiKey) {
        $ApiKey = Read-Host "API Key (leave empty if not needed)"
    }
    
    if (-not $Npm) {
        $Npm = Read-Host "NPM package (optional, e.g., @ai-sdk/anthropic)"
    }
    
    $provider = @{
        options = @{
            baseURL = $BaseUrl
        }
    }
    
    if ($ApiKey) { $provider.options.apiKey = $ApiKey }
    if ($Npm) { $provider.npm = $Npm }
    
    Write-Host ""
    Write-Host "Add models? (y/N): " -NoNewline
    $addModels = Read-Host
    
    if ($addModels -eq "y" -or $addModels -eq "Y") {
        $models = @{}
        
        while ($true) {
            Write-Host ""
            $modelId = Read-Host "Model ID (leave empty to finish)"
            if (-not $modelId) { break }
            
            $modelData = @{}
            
            $displayName = Read-Host "Display name (optional)"
            if ($displayName) { $modelData.name = $displayName }
            
            $contextLimit = Read-Host "Context limit (tokens, optional)"
            $outputLimit = Read-Host "Output limit (tokens, optional)"
            
            if ($contextLimit -or $outputLimit) {
                $modelData.limit = @{}
                if ($contextLimit) { $modelData.limit.context = [int]$contextLimit }
                if ($outputLimit) { $modelData.limit.output = [int]$outputLimit }
            }
            
            $reasoning = Read-Host "Supports reasoning? (y/N)"
            if ($reasoning -eq "y" -or $reasoning -eq "Y") { $modelData.reasoning = $true }
            
            $inputMod = Read-Host "Input modalities (comma-separated, e.g., text,image,pdf)"
            if ($inputMod) {
                $modelData.modalities = @{
                    input = $inputMod -split ',' | ForEach-Object { $_.Trim() }
                }
                $outputMod = Read-Host "Output modalities (comma-separated, default: text)"
                $modelData.modalities.output = if ($outputMod) { $outputMod -split ',' | ForEach-Object { $_.Trim() } } else { @("text") }
            }
            
            $models[$modelId] = $modelData
            Write-Host "✓ Added model: $modelId" -ForegroundColor Green
        }
        
        if ($models.Count -gt 0) {
            $provider.models = $models
        }
    }
    
    Add-Provider $Name $provider
}

if ($Template) {
    $templates = Get-Templates
    if ($templates[$Template]) {
        $t = $templates[$Template]
        $Name = if ($Name) { $Name } else { $t.Name }
        $BaseUrl = if ($BaseUrl) { $BaseUrl } else { $t.BaseUrl }
        $Npm = if ($Npm) { $Npm } else { $t.Npm }
        $ApiKey = if ($ApiKey) { $ApiKey } else { $t.ApiKey }
    } else {
        Write-Host "Unknown template: $Template" -ForegroundColor Red
        Write-Host "Available templates: $($templates.Keys -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

if ($Name -and $BaseUrl) {
    $provider = @{
        options = @{
            baseURL = $BaseUrl
        }
    }
    if ($ApiKey) { $provider.options.apiKey = $ApiKey }
    if ($Npm) { $provider.npm = $Npm }
    
    Add-Provider $Name $provider
} elseif (-not $Interactive) {
    Interactive-Wizard
} else {
    Interactive-Wizard
}
