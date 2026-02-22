#!/bin/bash
#
# CLIProxyAPI Uninstaller for Linux/macOS
#
# Completely removes CLIProxyAPI and all related files.
# By default, preserves auth files.
#
# Usage:
#   ./uninstall-cliproxyapi.sh              # Interactive, keeps auth
#   ./uninstall-cliproxyapi.sh --all        # Remove everything
#   ./uninstall-cliproxyapi.sh --keep-auth  # Keep OAuth tokens
#   ./uninstall-cliproxyapi.sh --force      # No confirmation
#

set -e

BIN_DIR="$HOME/bin"
CONFIG_DIR="$HOME/.cliproxyapi"
CLONE_DIR="$HOME/CLIProxyAPI"

ALL=false
KEEP_AUTH=true
FORCE=false

for arg in "$@"; do
    case $arg in
        --all) 
            ALL=true
            KEEP_AUTH=false
            ;;
        --keep-auth) KEEP_AUTH=true ;;
        --force) FORCE=true ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --all        Remove everything including auth files"
            echo "  --keep-auth  Keep OAuth tokens (default)"
            echo "  --force      No confirmation prompt"
            echo "  --help       Show this help"
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

write_step() { echo -e "${CYAN}[*] $1${NC}"; }
write_success() { echo -e "${GREEN}[+] $1${NC}"; }
write_warning() { echo -e "${YELLOW}[!] $1${NC}"; }
write_error() { echo -e "${RED}[-] $1${NC}"; }

get_size() {
    local path="$1"
    if [ -d "$path" ]; then
        du -sh "$path" 2>/dev/null | cut -f1
    elif [ -f "$path" ]; then
        du -h "$path" 2>/dev/null | cut -f1
    else
        echo "N/A"
    fi
}

echo -e "${RED}=========================================="
echo "  CLIProxyAPI Uninstaller"
echo "==========================================${NC}"

write_step "Scanning installation..."

TO_REMOVE=()
TO_KEEP=()

check_item() {
    local name="$1"
    local path="$2"
    local type="$3"
    local always="$4"
    
    if [ -e "$path" ] || compgen -G "$path" > /dev/null 2>&1; then
        local size=$(get_size "$path")
        local item="$name|$path|$type|$size"
        
        if [ "$always" = "true" ]; then
            TO_REMOVE+=("$item")
        elif [ "$KEEP_AUTH" = true ]; then
            TO_KEEP+=("$item")
        else
            TO_REMOVE+=("$item")
        fi
    fi
}

check_item "Binary" "$BIN_DIR/cliproxyapi" "file" "true"
check_item "Binary backup" "$BIN_DIR/cliproxyapi.old" "file" "true"
check_item "Install script" "$BIN_DIR/install-cliproxyapi.sh" "file" "true"
check_item "Update script" "$BIN_DIR/update-cliproxyapi.sh" "file" "true"
check_item "OAuth script" "$BIN_DIR/cliproxyapi-oauth.sh" "file" "true"
check_item "Start script" "$BIN_DIR/start-cliproxyapi.sh" "file" "true"
check_item "Uninstall script" "$BIN_DIR/uninstall-cliproxyapi.sh" "file" "true"
check_item "Clone directory" "$CLONE_DIR" "dir" "true"
check_item "Config (config.yaml)" "$CONFIG_DIR/config.yaml" "file" "true"
check_item "PID file" "$CONFIG_DIR/cliproxyapi.pid" "file" "true"
check_item "Logs directory" "$CONFIG_DIR/logs" "dir" "true"
check_item "Auth files (*.json)" "$CONFIG_DIR/*.json" "glob" "false"
check_item "Config directory" "$CONFIG_DIR" "dir" "false"

if [ ${#TO_REMOVE[@]} -eq 0 ]; then
    echo -e "\n${YELLOW}[!] Nothing to remove. CLIProxyAPI is not installed.${NC}"
    exit 0
fi

echo -e "\n${RED}[!] The following items will be REMOVED:${NC}"
for item in "${TO_REMOVE[@]}"; do
    IFS='|' read -r name path type size <<< "$item"
    echo -e "    - ${WHITE}$name${NC} ($size)"
    echo -e "      ${path}"
done

if [ ${#TO_KEEP[@]} -gt 0 ]; then
    echo -e "\n${GREEN}[*] The following items will be KEPT:${NC}"
    for item in "${TO_KEEP[@]}"; do
        IFS='|' read -r name path type size <<< "$item"
        echo -e "    - $name ($size)"
        echo -e "      $path"
    done
    echo -e "\n    ${CYAN}Use --all to remove everything${NC}"
fi

if [ "$FORCE" = false ]; then
    echo ""
    read -p "Are you sure you want to uninstall? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        echo -e "\n${YELLOW}[*] Uninstall cancelled.${NC}"
        exit 0
    fi
fi

write_step "Removing CLIProxyAPI..."
REMOVED=0
FAILED=0

for item in "${TO_REMOVE[@]}"; do
    IFS='|' read -r name path type size <<< "$item"
    
    if [ "$type" = "glob" ]; then
        for f in $path; do
            if [ -e "$f" ]; then
                if rm -f "$f" 2>/dev/null; then
                    write_success "Removed: $f"
                    ((REMOVED++))
                else
                    write_error "Failed: $f"
                    ((FAILED++))
                fi
            fi
        done
    elif [ "$type" = "dir" ]; then
        if [ -d "$path" ]; then
            if rm -rf "$path" 2>/dev/null; then
                write_success "Removed: $name"
                ((REMOVED++))
            else
                write_error "Failed: $name"
                ((FAILED++))
            fi
        fi
    else
        if [ -e "$path" ]; then
            if rm -f "$path" 2>/dev/null; then
                write_success "Removed: $name"
                ((REMOVED++))
            else
                write_error "Failed: $name"
                ((FAILED++))
            fi
        fi
    fi
done

if [ "$ALL" = true ] && [ -d "$CONFIG_DIR" ]; then
    rm -rf "$CONFIG_DIR" 2>/dev/null && write_success "Removed: Config directory"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "  Uninstall Complete!"
echo "==========================================${NC}"
echo "Removed: $REMOVED items"
[ $FAILED -gt 0 ] && echo -e "${RED}Failed:  $FAILED items${NC}"
[ ${#TO_KEEP[@]} -gt 0 ] && echo -e "${YELLOW}Kept:    ${#TO_KEEP[@]} items${NC}"

if [ ${#TO_KEEP[@]} -gt 0 ] && [ "$ALL" = false ]; then
    echo ""
    echo -e "${CYAN}To remove everything including auth files:${NC}"
    echo "  $0 --all --force"
fi

echo ""
