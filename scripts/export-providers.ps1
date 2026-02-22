<#
.SYNOPSIS
    Export or import custom AI providers configuration

.DESCRIPTION
    Export providers to JSON or YAML format, or import from a file.

.PARAMETER Export
    Export providers to file

.PARAMETER Import
    Import providers from file

.PARAMETER Format
    Export format: json (default) or yaml

.PARAMETER Output
    Output file path (default: providers.json or providers.yaml)

.PARAMETER Merge
    Merge with existing providers when importing (default: replace)

.EXAMPLE
    .\export-providers.ps1 -Export -Format json

.EXAMPLE
    .\export-providers.ps1 -Import -File providers.json

.EXAMPLE
    .\export-providers.ps1 -Export -Format yaml -Output my-providers.yaml
#>

param(
    [switch]$Export,
    [switch]$Import,
    [string]$File,
    [ValidateSet("json", "yaml")]
    [string]$Format = "json",
    [string]$Output,
    [switch]$Merge,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

$ProvidersPath = "$env:USERPROFILE\.cliproxyapi\providers.json"
$ProvidersDir = Split-Path $ProvidersPath -Parent

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
}

function ConvertTo-Yaml($data, $indent = 0) {
    $sb = [System.Text.StringBuilder]::new()
    $spaces = "  " * $indent
    
    if ($data -is [hashtable] -or $data -is [PSCustomObject]) {
        $props = if ($data -is [hashtable]) { $data.Keys } else { $data.PSObject.Properties }
        
        foreach ($prop in $props) {
            $key = if ($data -is [hashtable]) { $prop } else { $prop.Name }
            $value = if ($data -is [hashtable]) { $data[$key] } else { $prop.Value }
            
            if ($value -is [hashtable] -or $value -is [PSCustomObject] -or $value -is [array]) {
                [void]$sb.AppendLine("$spaces$key:")
                [void]$sb.Append((ConvertTo-Yaml $value ($indent + 1)))
            } elseif ($value -is [string]) {
                if ($value -match ":|`n|`"|'") {
                    [void]$sb.AppendLine("$spaces$key: `"$value`"")
                } else {
                    [void]$sb.AppendLine("$spaces$key: $value")
                }
            } elseif ($value -is [boolean]) {
                [void]$sb.AppendLine("$spaces$key: $($value.ToString().ToLower())")
            } elseif ($null -ne $value) {
                [void]$sb.AppendLine("$spaces$key: $value")
            }
        }
    } elseif ($data -is [array]) {
        foreach ($item in $data) {
            if ($item -is [hashtable] -or $item -is [PSCustomObject]) {
                [void]$sb.AppendLine("$spaces-")
                $subYaml = ConvertTo-Yaml $item ($indent + 1)
                [void]$sb.Append($subYaml -replace "^$spaces", "$spaces  ")
            } else {
                [void]$sb.AppendLine("$spaces- $item")
            }
        }
    }
    
    return $sb.ToString()
}

if ($Export) {
    $providers = Load-Providers
    
    if ($providers.PSObject.Properties.Count -eq 0) {
        Write-Host "No providers to export." -ForegroundColor Yellow
        exit 0
    }
    
    $data = @{
        '$schema' = "https://cliproxyapi.dev/schema/providers.json"
        providers = $providers
    }
    
    if (-not $Output) {
        $Output = if ($Format -eq "yaml") { "providers.yaml" } else { "providers.json" }
    }
    
    if ($Format -eq "yaml") {
        $yaml = ConvertTo-Yaml $data
        $yaml | Set-Content $Output -Encoding UTF8
    } else {
        $data | ConvertTo-Json -Depth 10 | Set-Content $Output -Encoding UTF8
    }
    
    Write-Host "✓ Exported $($providers.PSObject.Properties.Count) provider(s) to $Output" -ForegroundColor Green
    
} elseif ($Import) {
    if (-not $File) {
        Write-Host "Please specify -File parameter for import." -ForegroundColor Red
        exit 1
    }
    
    if (-not (Test-Path $File)) {
        Write-Host "File not found: $File" -ForegroundColor Red
        exit 1
    }
    
    $content = Get-Content $File -Raw
    
    try {
        $data = $content | ConvertFrom-Json
    } catch {
        Write-Host "Invalid JSON file: $File" -ForegroundColor Red
        exit 1
    }
    
    if (-not $data.providers) {
        Write-Host "Invalid providers file: missing 'providers' key" -ForegroundColor Red
        exit 1
    }
    
    $importedCount = $data.providers.PSObject.Properties.Count
    
    if ($Merge) {
        $existing = Load-Providers
        
        $data.providers.PSObject.Properties | ForEach-Object {
            $name = $_.Name
            $value = $_.Value
            
            if ($existing.PSObject.Properties[$name]) {
                Write-Host "  Updating: $name" -ForegroundColor Yellow
            } else {
                Write-Host "  Adding: $name" -ForegroundColor Green
            }
            
            $existing | Add-Member -MemberType NoteProperty -Name $name -Value $value -Force
        }
        
        Save-Providers $existing
        Write-Host "✓ Merged $importedCount provider(s)" -ForegroundColor Green
    } else {
        Save-Providers $data.providers
        Write-Host "✓ Imported $importedCount provider(s)" -ForegroundColor Green
    }
    
} else {
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Cyan
    Write-Host "  Export:  .\export-providers.ps1 -Export -Format json" -ForegroundColor White
    Write-Host "  Import:  .\export-providers.ps1 -Import -File providers.json" -ForegroundColor White
    Write-Host "  Merge:   .\export-providers.ps1 -Import -File providers.json -Merge" -ForegroundColor White
    Write-Host ""
}
