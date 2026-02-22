#!/usr/bin/env bash
#
# test-provider.sh - Test connection to a custom AI provider
#
# Usage:
#   ./test-provider.sh openrouter
#   ./test-provider.sh ollama --verbose
#
# Providers are read from ~/.cliproxyapi/providers.json

set -e

PROVIDERS_PATH="$HOME/.cliproxyapi/providers.json"

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <provider-name>

Test connection to a custom AI provider.

Arguments:
  provider-name    Name of the provider to test

Options:
  -v, --verbose    Show detailed response
  -h, --help       Show this help message

Examples:
  $(basename "$0") openrouter
  $(basename "$0") ollama --verbose

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
        *)       printf "%s\n" "$*" ;;
    esac
}

# Parse arguments
VERBOSE=false
PROVIDER_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose) VERBOSE=true; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) PROVIDER_NAME="$1"; shift ;;
    esac
done

if [[ -z "$PROVIDER_NAME" ]]; then
    echo "Error: Provider name is required"
    show_help
    exit 1
fi

# Check if providers file exists
if [[ ! -f "$PROVIDERS_PATH" ]]; then
    color_echo red "No providers configured yet."
    echo "Run 'add-provider.sh' to add a provider."
    exit 1
fi

# Load provider
provider=$(jq --arg n "$PROVIDER_NAME" '.providers[$n] // empty' "$PROVIDERS_PATH")

if [[ -z "$provider" || "$provider" == "null" ]]; then
    color_echo red "Provider '$PROVIDER_NAME' not found."
    echo ""
    echo "Available providers:"
    jq -r '.providers | keys[]' "$PROVIDERS_PATH" | while read -r name; do
        echo "  - $name"
    done
    exit 1
fi

base_url=$(echo "$provider" | jq -r '.options.baseURL')
api_key=$(echo "$provider" | jq -r '.options.apiKey // empty')

echo ""
color_echo cyan "Testing provider: $PROVIDER_NAME"
echo "  Base URL: $base_url"
echo ""

# Test connection
color_echo cyan "Sending request to $base_url/models..."

start_time=$(date +%s%N)

if command -v curl &>/dev/null; then
    if [[ -n "$api_key" ]]; then
        response=$(curl -s -w "\n---HTTP_STATUS:%{http_code}---" \
            -H "Authorization: Bearer $api_key" \
            -H "Content-Type: application/json" \
            --connect-timeout 15 \
            "$base_url/models" 2>&1)
    else
        response=$(curl -s -w "\n---HTTP_STATUS:%{http_code}---" \
            -H "Content-Type: application/json" \
            --connect-timeout 15 \
            "$base_url/models" 2>&1)
    fi
    
    http_code=$(echo "$response" | grep -o '---HTTP_STATUS:[0-9]*---' | grep -o '[0-9]*')
    body=$(echo "$response" | sed 's/---HTTP_STATUS:[0-9]*---//')
elif command -v wget &>/dev/null; then
    if [[ -n "$api_key" ]]; then
        body=$(wget -qO- --timeout=15 --header="Authorization: Bearer $api_key" "$base_url/models" 2>&1)
    else
        body=$(wget -qO- --timeout=15 "$base_url/models" 2>&1)
    fi
    http_code=200
else
    color_echo red "Neither curl nor wget is available."
    exit 1
fi

end_time=$(date +%s%N)
latency=$(( (end_time - start_time) / 1000000 ))

# Parse response
if [[ "$http_code" == "200" ]]; then
    color_echo green "Connection successful! (${latency}ms)"
    
    model_count=$(echo "$body" | jq '.data | length // 0' 2>/dev/null || echo "0")
    
    if [[ "$model_count" != "0" && "$model_count" != "null" ]]; then
        echo ""
        color_echo cyan "Available models: $model_count"
        
        if [[ "$VERBOSE" == true ]]; then
            echo "$body" | jq -r '.data[:10][] | "  - \(.id)"' 2>/dev/null || \
            echo "$body" | jq -r '.data[]?.id // .models[]?' 2>/dev/null | head -10 | while read -r m; do
                echo "  - $m"
            done
            [[ "$model_count" -gt 10 ]] && echo "  ... and $((model_count - 10)) more"
        fi
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        echo ""
        color_echo cyan "Response:"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
    fi
else
    color_echo red "Connection failed (HTTP $http_code)"
    
    if [[ -n "$body" ]]; then
        echo ""
        color_echo yellow "Response:"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
    fi
fi

echo ""
