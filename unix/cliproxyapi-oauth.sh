#!/bin/bash
#
# CLIProxyAPI OAuth Login Helper for Linux/macOS
#
# Interactive script to login to all supported OAuth providers.
# Run without parameters for interactive menu, or use flags for specific providers.
#
# Usage:
#   ./cliproxyapi-oauth.sh              # Interactive menu
#   ./cliproxyapi-oauth.sh --all        # Login to all providers
#   ./cliproxyapi-oauth.sh --gemini     # Login to Gemini only
#

set -e

CONFIG_DIR="$HOME/.cliproxyapi"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
BINARY="$HOME/bin/cliproxyapi"

ALL=false
GEMINI=false
ANTIGRAVITY=false
COPILOT=false
CODEX=false
CLAUDE=false
QWEN=false
IFLOW=false
KIRO=false

for arg in "$@"; do
    case $arg in
        --all) ALL=true ;;
        --gemini) GEMINI=true ;;
        --antigravity) ANTIGRAVITY=true ;;
        --copilot) COPILOT=true ;;
        --codex) CODEX=true ;;
        --claude) CLAUDE=true ;;
        --qwen) QWEN=true ;;
        --iflow) IFLOW=true ;;
        --kiro) KIRO=true ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --all          Login to all providers"
            echo "  --gemini       Login to Gemini CLI"
            echo "  --antigravity  Login to Antigravity"
            echo "  --copilot      Login to GitHub Copilot"
            echo "  --codex        Login to Codex"
            echo "  --claude       Login to Claude"
            echo "  --qwen         Login to Qwen"
            echo "  --iflow        Login to iFlow"
            echo "  --kiro         Login to Kiro (AWS)"
            echo "  --help         Show this help"
            exit 0
            ;;
    esac
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

if [ ! -f "$BINARY" ]; then
    echo -e "${RED}[-] cliproxyapi not found. Run install-cliproxyapi.sh first.${NC}"
    exit 1
fi

declare -A PROVIDERS
PROVIDERS[1]="Gemini CLI|--login"
PROVIDERS[2]="Antigravity|--antigravity-login"
PROVIDERS[3]="GitHub Copilot|--github-copilot-login"
PROVIDERS[4]="Codex|--codex-login"
PROVIDERS[5]="Claude|--claude-login"
PROVIDERS[6]="Qwen|--qwen-login"
PROVIDERS[7]="iFlow|--iflow-login"
PROVIDERS[8]="Kiro (AWS)|--kiro-aws-login"

declare -A FLAGS
FLAGS[gemini]="--login"
FLAGS[antigravity]="--antigravity-login"
FLAGS[copilot]="--github-copilot-login"
FLAGS[codex]="--codex-login"
FLAGS[claude]="--claude-login"
FLAGS[qwen]="--qwen-login"
FLAGS[iflow]="--iflow-login"
FLAGS[kiro]="--kiro-aws-login"

declare -A NAMES
NAMES[gemini]="Gemini CLI"
NAMES[antigravity]="Antigravity"
NAMES[copilot]="GitHub Copilot"
NAMES[codex]="Codex"
NAMES[claude]="Claude"
NAMES[qwen]="Qwen"
NAMES[iflow]="iFlow"
NAMES[kiro]="Kiro (AWS)"

run_login() {
    local name="$1"
    local flag="$2"
    echo -e "\n${CYAN}[*] Logging in to $name...${NC}"
    echo "    Command: $BINARY --config $CONFIG_FILE $flag"
    
    if "$BINARY" --config "$CONFIG_FILE" "$flag"; then
        echo -e "${GREEN}[+] $name login completed!${NC}"
    else
        echo -e "${YELLOW}[!] $name login may have issues (exit code: $?)${NC}"
    fi
}

ANY_FLAG=false
[ "$GEMINI" = true ] && ANY_FLAG=true
[ "$ANTIGRAVITY" = true ] && ANY_FLAG=true
[ "$COPILOT" = true ] && ANY_FLAG=true
[ "$CODEX" = true ] && ANY_FLAG=true
[ "$CLAUDE" = true ] && ANY_FLAG=true
[ "$QWEN" = true ] && ANY_FLAG=true
[ "$IFLOW" = true ] && ANY_FLAG=true
[ "$KIRO" = true ] && ANY_FLAG=true
[ "$ALL" = true ] && ANY_FLAG=true

if [ "$ANY_FLAG" = true ]; then
    echo -e "${MAGENTA}=== CLIProxyAPI OAuth Login ===${NC}"
    
    for key in "${!FLAGS[@]}"; do
        if [ "$ALL" = true ] || [ "${!key}" = true ]; then
            run_login "${NAMES[$key]}" "${FLAGS[$key]}"
        fi
    done
else
    echo -e "${MAGENTA}=========================================="
    echo "  CLIProxyAPI OAuth Login Menu"
    echo "==========================================${NC}"
    echo ""
    echo "Available providers:"
    for i in $(echo "${!PROVIDERS[@]}" | tr ' ' '\n' | sort -n); do
        IFS='|' read -r name flag <<< "${PROVIDERS[$i]}"
        echo "  $i. $name"
    done
    echo "  A. Login to ALL providers"
    echo "  Q. Quit"
    echo ""
    
    while true; do
        read -p "Select provider(s) [1-8, A, or Q]: " choice
        
        case "$choice" in
            [Qq])
                echo -e "${GREEN}Bye!${NC}"
                break
                ;;
            [Aa])
                echo -e "\n${YELLOW}Logging in to ALL providers...${NC}"
                for i in $(echo "${!PROVIDERS[@]}" | tr ' ' '\n' | sort -n); do
                    IFS='|' read -r name flag <<< "${PROVIDERS[$i]}"
                    run_login "$name" "$flag"
                    echo -e "\n${CYAN}Press Enter to continue to next provider...${NC}"
                    read
                done
                echo -e "\n${GREEN}[+] All logins completed!${NC}"
                break
                ;;
            *)
                IFS=',' read -ra SELECTIONS <<< "$choice"
                for sel in "${SELECTIONS[@]}"; do
                    sel=$(echo "$sel" | tr -d ' ')
                    if [[ "$sel" =~ ^[0-9]+$ ]] && [ -n "${PROVIDERS[$sel]}" ]; then
                        IFS='|' read -r name flag <<< "${PROVIDERS[$sel]}"
                        run_login "$name" "$flag"
                    elif [ -n "$sel" ]; then
                        echo -e "${YELLOW}[!] Invalid selection: $sel${NC}"
                    fi
                done
                echo ""
                ;;
        esac
    done
fi

echo ""
echo -e "${GREEN}=========================================="
echo "  Auth files saved in: $CONFIG_DIR"
echo "==========================================${NC}"
