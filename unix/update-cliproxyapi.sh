#!/bin/bash
#
# CLIProxyAPI Update Script for Linux/macOS
#
# Updates CLIProxyAPI to the latest version.
# - Pulls latest from repo OR downloads latest release
# - Rebuilds binary OR extracts pre-built
# - Preserves all config and auth files
#
# Usage:
#   ./update-cliproxyapi.sh              # Update from source
#   ./update-cliproxyapi.sh --prebuilt   # Use pre-built binary
#   ./update-cliproxyapi.sh --force      # Force update
#

set -e

REPO_URL="https://github.com/imrosyd/cliproxyapi.git"
RELEASE_API="https://api.github.com/repos/imrosyd/cliproxyapi/releases/latest"
BIN_DIR="$HOME/bin"
CONFIG_DIR="$HOME/.cliproxyapi"
CLONE_DIR="$HOME/cliproxyapi"
BINARY_NAME="cliproxyapi"

USE_PREBUILT=false
FORCE=false

for arg in "$@"; do
    case $arg in
        --prebuilt) USE_PREBUILT=true ;;
        --force) FORCE=true ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --prebuilt  Use pre-built binary"
            echo "  --force     Force update even if up-to-date"
            echo "  --help      Show this help"
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

write_step() { echo -e "\n${CYAN}[*] $1${NC}"; }
write_success() { echo -e "${GREEN}[+] $1${NC}"; }
write_warning() { echo -e "${YELLOW}[!] $1${NC}"; }
write_error() { echo -e "${RED}[-] $1${NC}"; }

detect_os() {
    case "$(uname -s)" in
        Darwin*) echo "darwin" ;;
        Linux*)  echo "linux" ;;
        *)       echo "unknown" ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "amd64" ;;
        arm64|aarch64) echo "arm64" ;;
        *)            echo "unknown" ;;
    esac
}

echo -e "${MAGENTA}=============================================="
echo "  CLIProxyAPI Updater"
echo "==============================================${NC}"

OS=$(detect_os)
ARCH=$(detect_arch)

write_step "Checking current installation..."
BINARY_PATH="$BIN_DIR/$BINARY_NAME"
if [ -f "$BINARY_PATH" ]; then
    FILE_DATE=$(stat -f "%Sm" "$BINARY_PATH" 2>/dev/null || stat -c "%y" "$BINARY_PATH" 2>/dev/null)
    echo "    Current binary: $FILE_DATE"
else
    write_warning "Binary not found. Run install-cliproxyapi.sh first."
    exit 1
fi

write_step "Fetching latest release info..."
RELEASE_INFO=$(curl -s "$RELEASE_API")
TAG_NAME=$(echo "$RELEASE_INFO" | grep -o '"tag_name": "[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
PUBLISHED=$(echo "$RELEASE_INFO" | grep -o '"published_at": "[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

if [ -n "$TAG_NAME" ]; then
    echo "    Latest version: $TAG_NAME"
    echo "    Published: $PUBLISHED"
else
    write_warning "Could not fetch release info"
fi

if [ "$USE_PREBUILT" = false ] && [ -d "$CLONE_DIR" ]; then
    write_step "Updating from source..."
    
    cd "$CLONE_DIR"
    
    echo "    Fetching latest changes..."
    git fetch origin main
    
    LOCAL_HASH=$(git rev-parse HEAD)
    REMOTE_HASH=$(git rev-parse origin/main)
    
    if [ "$LOCAL_HASH" = "$REMOTE_HASH" ] && [ "$FORCE" = false ]; then
        write_success "Already up to date!"
        exit 0
    fi
    
    echo "    Pulling latest changes..."
    git pull origin main --rebase || {
        write_warning "Git pull failed, trying reset..."
        git fetch origin main
        git reset --hard origin/main
    }
    
    echo "    Building binary..."
    go build -o "$BIN_DIR/$BINARY_NAME" ./cmd/server
    write_success "Binary rebuilt from source"
    
else
    write_step "Downloading latest pre-built binary..."
    
    ASSET_PATTERN="${OS}_${ARCH}"
    
    DOWNLOAD_URL=$(echo "$RELEASE_INFO" | grep -o "\"browser_download_url\": \"[^\"]*${ASSET_PATTERN}[^\"]*\"" | head -1 | sed 's/.*"\(https[^"]*\)".*/\1/')
    
    if [ -z "$DOWNLOAD_URL" ]; then
        write_error "Could not find binary for $OS $ARCH in latest release"
        exit 1
    fi
    
    TMP_DIR=$(mktemp -d)
    ZIP_FILE="$TMP_DIR/cliproxyapi.zip"
    
    echo "    Downloading from: $DOWNLOAD_URL"
    curl -sL "$DOWNLOAD_URL" -o "$ZIP_FILE"
    
    cd "$TMP_DIR"
    unzip -q -o "$ZIP_FILE" 2>/dev/null || tar -xzf "$ZIP_FILE" 2>/dev/null || { write_error "Failed to extract archive"; exit 1; }
    
    NEW_BINARY=$(find . -type f -name "cliproxyapi*" -executable 2>/dev/null | head -1)
    if [ -z "$NEW_BINARY" ]; then
        NEW_BINARY=$(find . -type f -name "cliproxyapi*" 2>/dev/null | head -1)
    fi
    
    if [ -n "$NEW_BINARY" ]; then
        BACKUP_PATH="$BIN_DIR/${BINARY_NAME}.old"
        if [ -f "$BINARY_PATH" ]; then
            cp "$BINARY_PATH" "$BACKUP_PATH"
        fi
        
        cp "$NEW_BINARY" "$BINARY_PATH"
        chmod +x "$BINARY_PATH"
        write_success "Binary updated: $BINARY_PATH"
        echo "    Backup saved: $BACKUP_PATH"
    else
        write_error "Could not find binary in extracted archive"
        exit 1
    fi
    
    rm -rf "$TMP_DIR"
fi

write_step "Verifying update..."
if [ -f "$BINARY_PATH" ]; then
    FILE_DATE=$(stat -f "%Sm" "$BINARY_PATH" 2>/dev/null || stat -c "%y" "$BINARY_PATH" 2>/dev/null)
    write_success "Update complete!"
    echo "    Binary updated: $FILE_DATE"
else
    write_error "Binary verification failed"
    exit 1
fi

echo ""
echo -e "${GREEN}=============================================="
echo "  Update Complete!"
echo "==============================================${NC}"
echo "Binary:  $BINARY_PATH"
echo "Config:  $CONFIG_DIR/config.yaml (preserved)"
echo "Auth:    $CONFIG_DIR/*.json (preserved)"
echo ""

# Restart service if running via systemd
if command -v systemctl &> /dev/null; then
    if systemctl --user is-active cliproxyapi &> /dev/null; then
        echo "Restarting systemd service..."
        systemctl --user restart cliproxyapi 2>/dev/null || true
        write_success "Service restarted with new binary"
    fi
fi

echo ""
echo "To start the server:"
echo "  cliproxyapi --config $CONFIG_DIR/config.yaml"
echo "=============================================="
