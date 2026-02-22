#!/bin/bash
#
# CLIProxyAPI Installation Script for Linux/macOS
#
# Complete one-click installer that sets up CLIProxyAPI.
# - Clones or downloads pre-built binary
# - Configures ~/.cliproxyapi/config.yaml
# - Provides OAuth login prompts
#
# Usage:
#   ./install-cliproxyapi.sh              # Build from source
#   ./install-cliproxyapi.sh --prebuilt   # Use pre-built binary
#   ./install-cliproxyapi.sh --force      # Force reinstall
#

set -e

REPO_URL="https://github.com/router-for-me/CLIProxyAPIPlus.git"
RELEASE_API="https://api.github.com/repos/router-for-me/CLIProxyAPIPlus/releases/latest"
BIN_DIR="$HOME/bin"
CONFIG_DIR="$HOME/.cliproxyapi"
CLONE_DIR="$HOME/CLIProxyAPI-source"
BINARY_NAME="cliproxyapi"

USE_PREBUILT=false
FORCE=false
SKIP_OAUTH=false

for arg in "$@"; do
    case $arg in
        --prebuilt) USE_PREBUILT=true ;;
        --force) FORCE=true ;;
        --skip-oauth) SKIP_OAUTH=true ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --prebuilt     Use pre-built binary (no Go required)"
            echo "  --force        Force reinstall"
            echo "  --skip-oauth   Skip OAuth instructions"
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
echo -e "  CLIProxyAPI Installer for Unix"
echo -e "==============================================${NC}"

OS=$(detect_os)
ARCH=$(detect_arch)

if [ "$OS" = "unknown" ]; then
    write_error "Unsupported OS: $(uname -s)"
    exit 1
fi

write_step "Detected: $OS $ARCH"

write_step "Checking prerequisites..."

if ! command -v git &> /dev/null; then
    write_error "Git is not installed. Please install Git first."
    echo "  Ubuntu/Debian: sudo apt install git"
    echo "  macOS: brew install git"
    echo "  Fedora: sudo dnf install git"
    exit 1
fi
write_success "Git found: $(git --version)"

if [ "$USE_PREBUILT" = false ]; then
    if ! command -v go &> /dev/null; then
        write_warning "Go is not installed. Switching to prebuilt binary mode."
        USE_PREBUILT=true
    else
        write_success "Go found: $(go version)"
    fi
fi

write_step "Creating directories..."
mkdir -p "$BIN_DIR"
mkdir -p "$CONFIG_DIR"
write_success "Directories ready"

if [ "$USE_PREBUILT" = true ]; then
    write_step "Downloading pre-built binary from GitHub Releases..."
    
    ASSET_PATTERN="${OS}_${ARCH}"
    if [ "$OS" = "darwin" ] && [ "$ARCH" = "amd64" ]; then
        ASSET_PATTERN="darwin_amd64"
    elif [ "$OS" = "darwin" ] && [ "$ARCH" = "arm64" ]; then
        ASSET_PATTERN="darwin_arm64"
    elif [ "$OS" = "linux" ] && [ "$ARCH" = "amd64" ]; then
        ASSET_PATTERN="linux_amd64"
    elif [ "$OS" = "linux" ] && [ "$ARCH" = "arm64" ]; then
        ASSET_PATTERN="linux_arm64"
    fi
    
    RELEASE_INFO=$(curl -s "$RELEASE_API")
    DOWNLOAD_URL=$(echo "$RELEASE_INFO" | grep -o "\"browser_download_url\": \"[^\"]*${ASSET_PATTERN}[^\"]*\"" | head -1 | sed 's/.*"\(https[^"]*\)".*/\1/')
    
    if [ -z "$DOWNLOAD_URL" ]; then
        write_error "Could not find binary for $OS $ARCH in latest release"
        exit 1
    fi
    
    TMP_DIR=$(mktemp -d)
    ZIP_FILE="$TMP_DIR/cliproxyapi.tar.gz"
    
    echo "    Downloading from: $DOWNLOAD_URL"
    curl -sL "$DOWNLOAD_URL" -o "$ZIP_FILE"
    
    OLD_DIR=$(pwd)
    cd "$TMP_DIR"
    tar -xzf "$ZIP_FILE" 2>/dev/null || unzip -q -o "$ZIP_FILE" 2>/dev/null || { write_error "Failed to extract archive"; exit 1; }
    
    BINARY_FILE=$(find . -type f \( -name "cli-proxy-api-plus" -o -name "cliproxyapi" -o -name "cli-proxy-api" \) -executable 2>/dev/null | head -1)
    if [ -z "$BINARY_FILE" ]; then
        BINARY_FILE=$(find . -type f \( -name "cli-proxy-api-plus" -o -name "cliproxyapi" -o -name "cli-proxy-api" \) 2>/dev/null | head -1)
    fi
    
    if [ -n "$BINARY_FILE" ] && [ -f "$BINARY_FILE" ]; then
        cp "$BINARY_FILE" "$BIN_DIR/$BINARY_NAME"
        chmod +x "$BIN_DIR/$BINARY_NAME"
        write_success "Binary installed: $BIN_DIR/$BINARY_NAME"
    else
        write_error "Could not find binary in extracted archive"
        ls -la "$TMP_DIR" 2>/dev/null
        exit 1
    fi
    
    cd "$OLD_DIR"
    rm -rf "$TMP_DIR"
else
    write_step "Building from source..."
    
    if [ -d "$CLONE_DIR" ]; then
        if [ "$FORCE" = true ] || [ ! -f "$CLONE_DIR/go.mod" ]; then
            echo "    Removing existing clone..."
            rm -rf "$CLONE_DIR"
            git clone --depth 1 "$REPO_URL" "$CLONE_DIR"
        else
            echo "    Updating existing clone..."
            cd "$CLONE_DIR"
            git pull origin main || true
        fi
    else
        echo "    Cloning repository..."
        git clone --depth 1 "$REPO_URL" "$CLONE_DIR"
    fi
    
    cd "$CLONE_DIR"
    echo "    Building binary..."
    go build -o "$BIN_DIR/$BINARY_NAME" ./cmd/server
    write_success "Binary built: $BIN_DIR/$BINARY_NAME"
    
    # Cleanup source directory
    cd "$HOME"
    rm -rf "$CLONE_DIR"
    write_success "Source directory cleaned up"
fi

write_step "Configuring ~/.cliproxyapi/config.yaml..."

CONFIG_PATH="$CONFIG_DIR/config.yaml"
if [ -f "$CONFIG_PATH" ] && [ "$FORCE" = false ]; then
    write_warning "config.yaml already exists, skipping (use --force to overwrite)"
else
    cat > "$CONFIG_PATH" << EOF
port: 8317
auth-dir: "$CONFIG_DIR"
api-keys:
  - "sk-dummy"
quota-exceeded:
  switch-project: true
  switch-preview-model: true
incognito-browser: true
request-retry: 3
remote-management:
  allow-remote: false
  secret-key: ""
  disable-control-panel: false
EOF
    write_success "config.yaml created"
fi

write_step "Verifying installation..."
BINARY_PATH="$BIN_DIR/$BINARY_NAME"
if [ -f "$BINARY_PATH" ]; then
    FILE_SIZE=$(stat -f%z "$BINARY_PATH" 2>/dev/null || stat -c%s "$BINARY_PATH" 2>/dev/null)
    if [ "$FILE_SIZE" -gt 1000000 ]; then
        SIZE_MB=$((FILE_SIZE / 1024 / 1024))
        write_success "Binary verification passed (${SIZE_MB} MB)"
    else
        write_error "Binary seems corrupted (too small)"
        exit 1
    fi
else
    write_error "Binary not found at $BINARY_PATH"
    exit 1
fi

write_step "Installing helper scripts..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for script in start-cliproxyapi cliproxyapi-oauth update-cliproxyapi uninstall-cliproxyapi gui-cliproxyapi cliproxyapi-benchmark; do
    if [ -f "$SCRIPT_DIR/${script}.sh" ]; then
        cp "$SCRIPT_DIR/${script}.sh" "$BIN_DIR/$script"
        chmod +x "$BIN_DIR/$script"
        write_success "Installed: $script"
    fi
done

GUI_SOURCE="$(dirname "$SCRIPT_DIR")/gui"
if [ -d "$GUI_SOURCE" ]; then
    mkdir -p "$CONFIG_DIR/gui"
    cp -r "$GUI_SOURCE"/* "$CONFIG_DIR/gui/" 2>/dev/null || true
    write_success "Installed: GUI files"
fi

write_step "Installing systemd service..."
if command -v systemctl &> /dev/null; then
    SYSTEMD_DIR="$HOME/.config/systemd/user"
    mkdir -p "$SYSTEMD_DIR"
    if [ -f "$SCRIPT_DIR/cliproxyapi.service" ]; then
        cp "$SCRIPT_DIR/cliproxyapi.service" "$SYSTEMD_DIR/cliproxyapi.service"
        write_success "Systemd service installed"
        echo "    Enable auto-start: start-cliproxyapi --enable"
        echo "    Or manually:       systemctl --user enable --now cliproxyapi"
    else
        write_warning "Service file not found, skipping"
    fi

    # Install auto-update timer
    if [ -f "$SCRIPT_DIR/cliproxyapi-update.service" ] && [ -f "$SCRIPT_DIR/cliproxyapi-update.timer" ]; then
        cp "$SCRIPT_DIR/cliproxyapi-update.service" "$SYSTEMD_DIR/cliproxyapi-update.service"
        cp "$SCRIPT_DIR/cliproxyapi-update.timer" "$SYSTEMD_DIR/cliproxyapi-update.timer"
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable --now cliproxyapi-update.timer 2>/dev/null || true
        write_success "Auto-update timer installed (weekly)"
        echo "    Check schedule:    systemctl --user list-timers cliproxyapi-update"
        echo "    Disable:           systemctl --user disable cliproxyapi-update.timer"
    else
        write_warning "Auto-update timer files not found, skipping"
    fi
else
    write_warning "systemd not available, skipping service installation"
fi

write_step "Configuring PATH..."
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    SHELL_RC=""
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        SHELL_RC="$HOME/.bashrc"
    fi
    
    if [ -n "$SHELL_RC" ]; then
        if ! grep -q "CLIProxyAPI" "$SHELL_RC" 2>/dev/null; then
            echo "" >> "$SHELL_RC"
            echo "# Added by CLIProxyAPI installer" >> "$SHELL_RC"
            echo "export PATH=\"\$PATH:$BIN_DIR\"" >> "$SHELL_RC"
        fi
        write_success "Added $BIN_DIR to PATH in $SHELL_RC"
    fi
    export PATH="$PATH:$BIN_DIR"
    PATH_ADDED=true
else
    write_success "$BIN_DIR already in PATH"
    PATH_ADDED=false
fi

if [ "$SKIP_OAUTH" = false ]; then
    echo ""
    echo -e "${YELLOW}=============================================="
    echo "  OAuth Login Setup (Optional)"
    echo "=============================================="
    echo "Run these commands to login to each provider:"
    echo ""
    echo "  # Gemini CLI"
    echo "  $BINARY_NAME --config $CONFIG_DIR/config.yaml --login"
    echo ""
    echo "  # Antigravity"
    echo "  $BINARY_NAME --config $CONFIG_DIR/config.yaml --antigravity-login"
    echo ""
    echo "  # GitHub Copilot"
    echo "  $BINARY_NAME --config $CONFIG_DIR/config.yaml --github-copilot-login"
    echo ""
    echo "  # Codex"
    echo "  $BINARY_NAME --config $CONFIG_DIR/config.yaml --codex-login"
    echo ""
    echo "  # Claude"
    echo "  $BINARY_NAME --config $CONFIG_DIR/config.yaml --claude-login"
    echo ""
    echo "  # Qwen"
    echo "  $BINARY_NAME --config $CONFIG_DIR/config.yaml --qwen-login"
    echo ""
    echo "  # iFlow"
    echo "  $BINARY_NAME --config $CONFIG_DIR/config.yaml --iflow-login"
    echo ""
    echo "  # Kiro (AWS)"
    echo "  $BINARY_NAME --config $CONFIG_DIR/config.yaml --kiro-aws-login"
    echo -e "==============================================${NC}"
fi

echo ""
echo -e "${GREEN}=============================================="
echo -e "  Installation Complete!"
echo -e "==============================================${NC}"
echo ""
echo "Installed Files:"
echo "  Binary:   $BIN_DIR/$BINARY_NAME"
echo "  Config:   $CONFIG_DIR/config.yaml"
echo ""
echo "Available Scripts (in $BIN_DIR):"
echo "  start-cliproxyapi     Start/stop/restart server"
echo "  cliproxyapi-oauth     Login to OAuth providers"
echo "  update-cliproxyapi    Update to latest version"
echo "  uninstall-cliproxyapi Remove everything"
echo ""
echo "Quick Start:"
echo "  1. Start server:    start-cliproxyapi -b"
echo "  2. Login OAuth:     cliproxyapi-oauth --all"
echo "  3. Test endpoint:   curl http://localhost:8317/v1/models"

if [ "$PATH_ADDED" = true ]; then
    echo ""
    echo -e "${YELLOW}NOTE: Restart your terminal or run: source ~/.bashrc (or ~/.zshrc)${NC}"
fi

echo ""
echo -e "${GREEN}==============================================${NC}"
