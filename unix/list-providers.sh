#!/usr/bin/env bash
#
# list-providers.sh - List custom AI providers for CLIProxyAPI
#
# Usage:
#   ./list-providers.sh
#   ./list-providers.sh --json
#   ./list-providers.sh --verbose
#
# Providers are read from ~/.cliproxyapi/providers.json

set -e

PROVIDERS_PATH="$HOME/.cliproxyapi/providers.json"

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

List custom AI providers configured for CLIProxyAPI.

Options:
  -j, --json       Output as JSON
  -v, --verbose    Show detailed information
  -h, --help       Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") --json
  $(basename "$0") --verbose

Provider file: ~/.cliproxyapi/providers.json
EOF
}

color_echo() {
    local color=$1
    shift
    case $color in
        red)     printf "\033[0;31m%s\033[0m\n" "$*" ;;
        green)   printf "\033[0;32m%s\033[0m\n" "$*" ;;
        yellow)  printf "\033[0;33m%s\033[0m\n" "$*" ;;
        cyan)    printf "\033[0;36m%s\033[0m\n" "$*" ;;
        magenta) printf "\033[0;35m%s\033[0m\n" "$*" ;;
        blue)    printf "\033[0;34m%s\033[0m\n" "$*" ;;
        *)       printf "%s\n" "$*" ;;
    esac
}

# Parse arguments
JSON_OUTPUT=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -j|--json) JSON_OUTPUT=true; shift ;;
        -v|--verbose) VERBOSE=true; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

# Check if providers file exists
if [[ ! -f "$PROVIDERS_PATH" ]]; then
    if [[ "$JSON_OUTPUT" == true ]]; then
        echo '{"providers":{},"count":0}'
    else
        color_echo yellow "No providers configured yet."
        echo ""
        echo "Run 'add-provider.sh' to add a provider."
    fi
    exit 0
fi

# Load providers
providers_json=$(cat "$PROVIDERS_PATH")

# JSON output
if [[ "$JSON_OUTPUT" == true ]]; then
    count=$(echo "$providers_json" | jq '.providers | length')
    echo "$providers_json" | jq --argjson c "$count" '. + {count: $c}'
    exit 0
fi

# Count providers
count=$(echo "$providers_json" | jq '.providers | length')

if [[ "$count" -eq 0 ]]; then
    color_echo yellow "No providers configured yet."
    echo ""
    echo "Run 'add-provider.sh' to add a provider."
    exit 0
fi

echo ""
color_echo magenta "========================================"
color_echo magenta "  CLIProxyAPI - Custom Providers"
color_echo magenta "========================================"
echo ""

# List providers
echo "$providers_json" | jq -r '.providers | keys[]' | while read -r name; do
    provider=$(echo "$providers_json" | jq --arg n "$name" '.providers[$n]')
    base_url=$(echo "$provider" | jq -r '.options.baseURL // "—"')
    npm=$(echo "$provider" | jq -r '.npm // empty')
    model_count=$(echo "$provider" | jq '.models | length // 0')
    
    color_echo cyan "Provider: $name"
    echo "  Base URL: $base_url"
    [[ -n "$npm" ]] && echo "  NPM:      $npm"
    echo "  Models:   $model_count"
    
    if [[ "$VERBOSE" == true ]]; then
        api_key=$(echo "$provider" | jq -r '.options.apiKey // empty')
        if [[ -n "$api_key" ]]; then
            masked_key="${api_key:0:8}...${api_key: -4}"
            echo "  API Key:  $masked_key"
        fi
        
        headers=$(echo "$provider" | jq -r '.options.headers // empty')
        [[ -n "$headers" && "$headers" != "null" ]] && echo "  Headers:  $headers"
        
        if [[ "$model_count" -gt 0 ]]; then
            echo "  Model List:"
            echo "$provider" | jq -r '.models | to_entries[] | "    - \(.key) (\(.value.name // .key))"' 2>/dev/null || \
            echo "$provider" | jq -r '.models | keys[] | "    - \(.)"'
        fi
    fi
    echo ""
done

color_echo green "Total: $count provider(s)"
echo ""
