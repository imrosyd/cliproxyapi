#!/usr/bin/env bash
#
# add-provider.sh - Add a custom AI provider to CLIProxyAPI
#
# Usage:
#   ./add-provider.sh --template openrouter --api-key "sk-or-xxx"
#   ./add-provider.sh --name "my-provider" --base-url "https://api.example.com/v1"
#
# Providers are saved to ~/.cliproxyapi/providers.json

set -e

PROVIDERS_PATH="$HOME/.cliproxyapi/providers.json"
PROVIDERS_DIR="$(dirname "$PROVIDERS_PATH")"

TEMPLATES='{
  "openrouter": {"name": "openrouter", "npm": null, "baseURL": "https://openrouter.ai/api/v1", "help": "Get API key from https://openrouter.ai/keys"},
  "ollama": {"name": "ollama", "npm": null, "baseURL": "http://localhost:11434/v1", "help": "No API key needed for local Ollama"},
  "lmstudio": {"name": "lmstudio", "npm": null, "baseURL": "http://localhost:1234/v1", "help": "No API key needed for local LM Studio"},
  "together": {"name": "together", "npm": "@together-ai/sdk", "baseURL": "https://api.together.xyz/v1", "help": "Get API key from https://api.together.xyz"},
  "groq": {"name": "groq", "npm": "groq-sdk", "baseURL": "https://api.groq.com/openai/v1", "help": "Get API key from https://console.groq.com"},
  "deepseek": {"name": "deepseek", "npm": null, "baseURL": "https://api.deepseek.com/v1", "help": "Get API key from https://platform.deepseek.com"}
}'

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Add a custom AI provider to CLIProxyAPI.

Options:
  -n, --name NAME         Provider name (lowercase alphanumeric with dashes)
  -u, --base-url URL      API base URL
  -k, --api-key KEY       API key for authentication
  -p, --npm PACKAGE       NPM package name for SDK
  -t, --template NAME     Use pre-defined template (openrouter, ollama, lmstudio, together, groq, deepseek)
  -i, --interactive       Interactive mode with prompts
  -f, --force             Overwrite existing provider
  -h, --help              Show this help message

Examples:
  $(basename "$0") --template openrouter --api-key "sk-or-xxx"
  $(basename "$0") -n "my-provider" -u "https://api.example.com/v1" -k "my-key"
  $(basename "$0") -i

Templates:
  openrouter  - OpenRouter (100+ models)
  ollama      - Local Ollama
  lmstudio    - Local LM Studio
  together    - Together AI
  groq        - Groq (fast inference)
  deepseek    - DeepSeek API

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
        *)       printf "%s\n" "$*" ;;
    esac
}

step() { color_echo cyan "  -> $*"; }
success() { color_echo green "  [OK] $*"; }
info() { color_echo yellow "  [i] $*"; }
error() { color_echo red "  [-] $*" >&2; }

load_providers() {
    if [[ -f "$PROVIDERS_PATH" ]]; then
        cat "$PROVIDERS_PATH"
    else
        echo '{"providers":{}}'
    fi
}

save_providers() {
    local data="$1"
    mkdir -p "$PROVIDERS_DIR"
    echo "$data" > "$PROVIDERS_PATH"
}

test_connection() {
    local base_url="$1"
    local api_key="$2"
    
    local auth_header=""
    if [[ -n "$api_key" ]]; then
        auth_header="-H \"Authorization: Bearer $api_key\""
    fi
    
    if command -v curl &>/dev/null; then
        local response
        response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$base_url/models" 2>/dev/null || echo "000")
        [[ "$response" == "200" ]]
    elif command -v wget &>/dev/null; then
        wget -q --spider --timeout=10 "$base_url/models" 2>/dev/null
    else
        return 1
    fi
}

validate_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-z0-9-]+$ ]]; then
        error "Provider name must be lowercase alphanumeric with dashes"
        return 1
    fi
}

# Parse arguments
NAME=""
BASE_URL=""
API_KEY=""
NPM=""
TEMPLATE=""
FORCE=false
INTERACTIVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name) NAME="$2"; shift 2 ;;
        -u|--base-url) BASE_URL="$2"; shift 2 ;;
        -k|--api-key) API_KEY="$2"; shift 2 ;;
        -p|--npm) NPM="$2"; shift 2 ;;
        -t|--template) TEMPLATE="$2"; shift 2 ;;
        -f|--force) FORCE=true; shift ;;
        -i|--interactive) INTERACTIVE=true; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) error "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

echo ""
color_echo magenta "========================================"
color_echo magenta "  CLIProxyAPI - Add Custom Provider"
color_echo magenta "========================================"
echo ""

# Apply template if specified
if [[ -n "$TEMPLATE" ]]; then
    template_data=$(echo "$TEMPLATES" | jq -r --arg t "$TEMPLATE" '.[$t] // empty')
    if [[ -z "$template_data" || "$template_data" == "null" ]]; then
        error "Unknown template: $TEMPLATE"
        info "Available: openrouter, ollama, lmstudio, together, groq, deepseek"
        exit 1
    fi
    
    info "Using template: $TEMPLATE"
    template_help=$(echo "$template_data" | jq -r '.help // empty')
    [[ -n "$template_help" ]] && info "$template_help"
    
    [[ -z "$NAME" ]] && NAME=$(echo "$template_data" | jq -r '.name')
    [[ -z "$BASE_URL" ]] && BASE_URL=$(echo "$template_data" | jq -r '.baseURL')
    [[ -z "$NPM" ]] && NPM=$(echo "$template_data" | jq -r '.npm // empty')
    template_api_key=$(echo "$template_data" | jq -r '.apiKey // empty')
    [[ -z "$API_KEY" && -n "$template_api_key" ]] && API_KEY="$template_api_key"
fi

# Interactive mode
if [[ "$INTERACTIVE" == true ]]; then
    if [[ -z "$NAME" ]]; then
        read -rp "Provider name (lowercase, alphanumeric, dash): " NAME
    fi
    if [[ -z "$BASE_URL" ]]; then
        read -rp "Base URL (e.g., https://api.example.com/v1): " BASE_URL
    fi
    if [[ -z "$API_KEY" ]]; then
        read -rp "API Key (leave empty if not required): " API_KEY
    fi
    if [[ -z "$NPM" ]]; then
        read -rp "NPM package name (optional): " NPM
    fi
fi

# Validate
if [[ -z "$NAME" ]]; then
    error "Provider name is required"
    exit 1
fi
validate_name "$NAME" || exit 1

if [[ -z "$BASE_URL" ]]; then
    error "Base URL is required"
    exit 1
fi

# Check if provider exists
providers_json=$(load_providers)
existing=$(echo "$providers_json" | jq -r --arg n "$NAME" '.providers[$n] // empty')
if [[ -n "$existing" && "$FORCE" == false ]]; then
    error "Provider '$NAME' already exists. Use --force to overwrite."
    exit 1
fi

# Test connection
step "Testing connection to $BASE_URL..."
if test_connection "$BASE_URL" "$API_KEY"; then
    success "Connection successful"
else
    info "Could not verify connection (this may be normal for some providers)"
fi

# Build provider object
provider_obj=$(jq -n \
    --arg base_url "$BASE_URL" \
    --arg api_key "$API_KEY" \
    --arg npm "$NPM" \
    '{
        options: {
            baseURL: $base_url
        } + (if $api_key != "" then {apiKey: $api_key} else {} end)
    } + (if $npm != "" then {npm: $npm} else {} end)')

# Add models interactively
declare -A models
echo ""
color_echo cyan "Add models (leave Model ID empty to finish):"

while true; do
    echo ""
    read -rp "  Model ID (e.g., gpt-4o): " model_id
    [[ -z "$model_id" ]] && break
    
    read -rp "  Display name (optional): " display_name
    read -rp "  Context limit in tokens (optional): " context_limit
    read -rp "  Output limit in tokens (optional): " output_limit
    read -rp "  Supports reasoning? (y/N): " reasoning
    read -rp "  Input modalities (comma-separated: text,image,pdf): " input_mod
    read -rp "  Output modalities (comma-separated: text,image): " output_mod
    
    # Build model JSON
    model_json="{}"
    [[ -n "$display_name" ]] && model_json=$(echo "$model_json" | jq --arg n "$display_name" '. + {name: $n}')
    [[ "$reasoning" =~ ^[Yy]$ ]] && model_json=$(echo "$model_json" | jq '. + {reasoning: true}')
    
    limits_json="{}"
    [[ -n "$context_limit" && "$context_limit" =~ ^[0-9]+$ ]] && limits_json=$(echo "$limits_json" | jq --argjson c "$context_limit" '. + {context: $c}')
    [[ -n "$output_limit" && "$output_limit" =~ ^[0-9]+$ ]] && limits_json=$(echo "$limits_json" | jq --argjson o "$output_limit" '. + {output: $o}')
    [[ "$limits_json" != "{}" ]] && model_json=$(echo "$model_json" | jq --argjson l "$limits_json" '. + {limit: $l}')
    
    modalities_json="{}"
    [[ -n "$input_mod" ]] && modalities_json=$(echo "$modalities_json" | jq --arg i "$input_mod" '. + {input: ($i | split(",") | map(gsub("^\\s+|\\s+$"; "")))}')
    [[ -n "$output_mod" ]] && modalities_json=$(echo "$modalities_json" | jq --arg o "$output_mod" '. + {output: ($o | split(",") | map(gsub("^\\s+|\\s+$"; "")))}')
    [[ "$modalities_json" != "{}" ]] && model_json=$(echo "$model_json" | jq --argjson m "$modalities_json" '. + {modalities: $m}')
    
    [[ "$model_json" == "{}" ]] && model_json='{"name": "'"$model_id"'"}'
    
    models["$model_id"]="$model_json"
    success "Model added: $model_id"
done

# Add models to provider
if [[ ${#models[@]} -gt 0 ]]; then
    models_json="{}"
    for mid in "${!models[@]}"; do
        models_json=$(echo "$models_json" | jq --arg k "$mid" --argjson v "${models[$mid]}" '. + {($k): $v}')
    done
    provider_obj=$(echo "$provider_obj" | jq --argjson m "$models_json" '. + {models: $m}')
fi

# Save
new_providers=$(echo "$providers_json" | jq --arg n "$NAME" --argjson p "$provider_obj" '
    .providers[$n] = $p |
    .["$schema"] = "https://cliproxyapi.dev/schema/providers.json"
')
save_providers "$new_providers"

echo ""
success "Provider '$NAME' saved to $PROVIDERS_PATH"
echo ""
color_echo cyan "Provider summary:"
echo "  Name:      $NAME"
echo "  Base URL:  $BASE_URL"
echo "  Models:    ${#models[@]}"
[[ -n "$NPM" ]] && echo "  NPM:       $NPM"
echo ""
