#!/usr/bin/env bash
#
# export-providers.sh - Export custom AI providers configuration
#
# Usage:
#   ./export-providers.sh                    # Export as JSON (default)
#   ./export-providers.sh --format yaml      # Export as YAML
#   ./export-providers.sh -o providers.json  # Specify output file
#
# Providers are read from ~/.cliproxyapi/providers.json

set -e

PROVIDERS_PATH="$HOME/.cliproxyapi/providers.json"

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Export custom AI providers configuration.

Options:
  -f, --format FORMAT   Output format: json (default), yaml
  -o, --output FILE     Output file path (default: stdout)
  -c, --clipboard       Copy to clipboard
  -h, --help            Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") --format yaml
  $(basename "$0") -o providers.json
  $(basename "$0") --clipboard

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

json_to_yaml() {
    local json="$1"
    
    if ! command -v python3 &>/dev/null; then
        color_echo red "Python3 is required for YAML export"
        exit 1
    fi
    
    python3 << PYTHON_SCRIPT
import json
import sys

def json_to_yaml(obj, indent=0):
    yaml = ""
    prefix = "  " * indent
    
    if isinstance(obj, dict):
        if not obj:
            return "{}\n"
        for key, value in obj.items():
            if isinstance(value, (dict, list)) and value:
                yaml += f"{prefix}{key}:\n"
                yaml += json_to_yaml(value, indent + 1)
            elif isinstance(value, list) and not value:
                yaml += f"{prefix}{key}: []\n"
            elif isinstance(value, dict) and not value:
                yaml += f"{prefix}{key}: {{}}\n"
            elif isinstance(value, str):
                if "\n" in value or ":" in value or '"' in value:
                    yaml += f'{prefix}{key}: "{value}"\n'
                else:
                    yaml += f"{prefix}{key}: {value}\n"
            elif isinstance(value, bool):
                yaml += f"{prefix}{key}: {str(value).lower()}\n"
            elif value is None:
                yaml += f"{prefix}{key}: null\n"
            else:
                yaml += f"{prefix}{key}: {value}\n"
    elif isinstance(obj, list):
        if not obj:
            return "[]\n"
        for item in obj:
            if isinstance(item, dict):
                yaml += f"{prefix}-\n"
                for key, value in item.items():
                    if isinstance(value, (dict, list)) and value:
                        yaml += f"{prefix}  {key}:\n"
                        yaml += json_to_yaml(value, indent + 2)
                    elif isinstance(value, str):
                        yaml += f"{prefix}  {key}: {value}\n"
                    elif isinstance(value, bool):
                        yaml += f"{prefix}  {key}: {str(value).lower()}\n"
                    elif value is None:
                        yaml += f"{prefix}  {key}: null\n"
                    else:
                        yaml += f"{prefix}  {key}: {value}\n"
            elif isinstance(item, str):
                yaml += f"{prefix}- {item}\n"
            else:
                yaml += f"{prefix}- {item}\n"
    
    return yaml

data = json.loads('''$json''')
print(json_to_yaml(data))
PYTHON_SCRIPT
}

# Parse arguments
FORMAT="json"
OUTPUT_FILE=""
CLIPBOARD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--format) FORMAT="$2"; shift 2 ;;
        -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
        -c|--clipboard) CLIPBOARD=true; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

# Validate format
if [[ "$FORMAT" != "json" && "$FORMAT" != "yaml" ]]; then
    color_echo red "Invalid format: $FORMAT. Use 'json' or 'yaml'."
    exit 1
fi

# Check if providers file exists
if [[ ! -f "$PROVIDERS_PATH" ]]; then
    color_echo red "No providers configured yet."
    echo "Run 'add-provider.sh' to add a provider."
    exit 1
fi

# Load providers
providers_json=$(cat "$PROVIDERS_PATH")

# Check if empty
count=$(echo "$providers_json" | jq '.providers | length')
if [[ "$count" -eq 0 ]]; then
    color_echo yellow "No providers to export."
    exit 0
fi

# Convert format
if [[ "$FORMAT" == "yaml" ]]; then
    output=$(json_to_yaml "$providers_json")
else
    output=$(echo "$providers_json" | jq '.')
fi

# Output
if [[ -n "$OUTPUT_FILE" ]]; then
    echo "$output" > "$OUTPUT_FILE"
    color_echo green "Exported $count provider(s) to $OUTPUT_FILE"
elif [[ "$CLIPBOARD" == true ]]; then
    if command -v pbcopy &>/dev/null; then
        echo "$output" | pbcopy
        color_echo green "Copied $count provider(s) to clipboard"
    elif command -v xclip &>/dev/null; then
        echo "$output" | xclip -selection clipboard
        color_echo green "Copied $count provider(s) to clipboard"
    elif command -v xsel &>/dev/null; then
        echo "$output" | xsel --clipboard --input
        color_echo green "Copied $count provider(s) to clipboard"
    else
        color_echo red "No clipboard utility found (pbcopy, xclip, or xsel)"
        echo "$output"
    fi
else
    echo "$output"
fi
