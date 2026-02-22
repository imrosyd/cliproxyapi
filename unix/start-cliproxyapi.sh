#!/bin/bash
#
# CLIProxyAPI Server Manager for Linux/macOS
#
# Start, stop, and manage the CLIProxyAPI proxy server.
#
# Usage:
#   ./start-cliproxyapi.sh              # Start in foreground
#   ./start-cliproxyapi.sh -b           # Start in background
#   ./start-cliproxyapi.sh --status     # Check if running
#   ./start-cliproxyapi.sh --stop       # Stop server
#   ./start-cliproxyapi.sh --logs       # View logs
#   ./start-cliproxyapi.sh --enable     # Enable systemd auto-start
#   ./start-cliproxyapi.sh --disable    # Disable systemd auto-start
#

set -e

BINARY="$HOME/bin/cliproxyapi"
CONFIG="$HOME/.cliproxyapi/config.yaml"
LOG_DIR="$HOME/.cliproxyapi/logs"
PID_FILE="$HOME/.cliproxyapi/cliproxyapi.pid"
SERVICE_NAME="cliproxyapi"
PORT=8317
PROCESS_NAMES="cliproxyapi|cli-proxy-api"

BACKGROUND=false
STATUS=false
STOP=false
LOGS=false
RESTART=false
ENABLE=false
DISABLE=false

for arg in "$@"; do
    case $arg in
        -b|--background) BACKGROUND=true ;;
        --status) STATUS=true ;;
        --stop) STOP=true ;;
        --logs) LOGS=true ;;
        --restart) RESTART=true ;;
        --enable) ENABLE=true ;;
        --disable) DISABLE=true ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -b, --background  Start in background"
            echo "  --status          Check server status"
            echo "  --stop            Stop server"
            echo "  --logs            View logs"
            echo "  --restart         Restart server"
            echo "  --enable          Enable systemd auto-start on boot"
            echo "  --disable         Disable systemd auto-start"
            echo "  --help            Show this help"
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

get_server_pid() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            echo "$PID"
            return
        fi
    fi
    
    PID=$(pgrep -f "cliproxyapi.*config.yaml" 2>/dev/null | head -1)
    if [ -n "$PID" ]; then
        echo "$PID"
        return
    fi
    
    echo ""
}

is_port_in_use() {
    if command -v lsof &> /dev/null; then
        lsof -i :$PORT &> /dev/null
    elif command -v ss &> /dev/null; then
        ss -ln | grep -q ":$PORT "
    elif command -v netstat &> /dev/null; then
        netstat -ln | grep -q ":$PORT "
    else
        return 1
    fi
}

show_status() {
    echo -e "\n${MAGENTA}=== CLIProxyAPI Status ===${NC}"
    
    PID=$(get_server_pid)
    if [ -n "$PID" ]; then
        write_success "Server is RUNNING"
        echo "  PID: $PID"
        
        if command -v ps &> /dev/null; then
            MEM=$(ps -o rss= -p "$PID" 2>/dev/null | awk '{printf "%.1f MB", $1/1024}')
            CPU=$(ps -o %cpu= -p "$PID" 2>/dev/null || echo "N/A")
            START=$(ps -o lstart= -p "$PID" 2>/dev/null || echo "N/A")
            echo "  Memory: $MEM"
            echo "  CPU: $CPU%"
            echo "  Started: $START"
        fi
    else
        write_warning "Server is NOT running"
    fi
    
    # Systemd service status
    if command -v systemctl &> /dev/null; then
        if systemctl --user is-enabled "$SERVICE_NAME" &> /dev/null; then
            SYSTEMD_STATE=$(systemctl --user is-active "$SERVICE_NAME" 2>/dev/null || echo "unknown")
            echo -e "\n  Systemd: ${GREEN}enabled${NC} (${SYSTEMD_STATE})"
        else
            echo -e "\n  Systemd: ${YELLOW}disabled${NC}"
            echo "  Enable auto-start: $0 --enable"
        fi
    fi
    
    if is_port_in_use; then
        echo -e "\n${GREEN}Port $PORT is in use${NC}"
    else
        echo -e "\n${YELLOW}Port $PORT is free${NC}"
    fi
    
    if command -v curl &> /dev/null; then
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/v1/models" --connect-timeout 2 2>/dev/null || echo "000")
        if [ "$RESPONSE" = "200" ]; then
            write_success "API endpoint responding (HTTP $RESPONSE)"
        else
            write_warning "API endpoint not responding"
        fi
    fi
    
    echo ""
}

stop_server() {
    PID=$(get_server_pid)
    if [ -n "$PID" ]; then
        write_step "Stopping server (PID: $PID)..."
        kill "$PID" 2>/dev/null || true
        sleep 1
        
        if kill -0 "$PID" 2>/dev/null; then
            write_step "Force killing server..."
            kill -9 "$PID" 2>/dev/null || true
        fi
        
        rm -f "$PID_FILE"
        write_success "Server stopped"
    else
        write_warning "Server is not running"
    fi
}

show_logs() {
    mkdir -p "$LOG_DIR"
    
    LATEST_LOG=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
    
    if [ -n "$LATEST_LOG" ]; then
        write_step "Showing logs from: $(basename "$LATEST_LOG")"
        echo -e "${CYAN}Press Ctrl+C to exit${NC}\n"
        tail -f "$LATEST_LOG"
    else
        write_warning "No log files found in $LOG_DIR"
        echo "Server may be running without file logging."
        echo "Start with: $BINARY --config $CONFIG"
    fi
}

start_server() {
    PID=$(get_server_pid)
    if [ -n "$PID" ]; then
        write_warning "Server is already running!"
        show_status
        return
    fi
    
    if [ ! -f "$BINARY" ]; then
        write_error "Binary not found: $BINARY"
        echo "Run install-cliproxyapi.sh first."
        exit 1
    fi
    
    if [ ! -f "$CONFIG" ]; then
        write_error "Config not found: $CONFIG"
        echo "Run install-cliproxyapi.sh first."
        exit 1
    fi
    
    mkdir -p "$LOG_DIR"
    
    if [ "$BACKGROUND" = true ]; then
        write_step "Starting server in background..."
        nohup "$BINARY" --config "$CONFIG" > "$LOG_DIR/server.log" 2>&1 &
        echo $! > "$PID_FILE"
        sleep 2
        
        PID=$(get_server_pid)
        if [ -n "$PID" ]; then
            write_success "Server started in background (PID: $PID)"
            echo ""
            echo "Endpoint: http://localhost:$PORT/v1"
            echo "To stop:   $0 --stop"
            echo "To status: $0 --status"
            echo "Logs:      $LOG_DIR/server.log"
        else
            write_error "Server failed to start"
            echo "Check logs: $LOG_DIR/server.log"
            exit 1
        fi
    else
        echo -e "${MAGENTA}=== CLIProxyAPI Server ===${NC}"
        echo "Config:   $CONFIG"
        echo "Endpoint: http://localhost:$PORT/v1"
        echo -e "${CYAN}Press Ctrl+C to stop${NC}\n"
        
        exec "$BINARY" --config "$CONFIG"
    fi
}

enable_service() {
    if ! command -v systemctl &> /dev/null; then
        write_error "systemctl not found. Systemd is required for this feature."
        exit 1
    fi
    
    SERVICE_FILE="$HOME/.config/systemd/user/$SERVICE_NAME.service"
    if [ ! -f "$SERVICE_FILE" ]; then
        write_error "Service file not found: $SERVICE_FILE"
        echo "Run install-cliproxyapi.sh to install the systemd service."
        exit 1
    fi
    
    write_step "Enabling $SERVICE_NAME service..."
    systemctl --user daemon-reload
    systemctl --user enable "$SERVICE_NAME"
    systemctl --user start "$SERVICE_NAME"
    write_success "Service enabled and started"
    echo ""
    echo "The server will now auto-start on login."
    echo "  Status:  systemctl --user status $SERVICE_NAME"
    echo "  Logs:    journalctl --user -u $SERVICE_NAME -f"
    
    # Enable lingering so service runs even without login session
    if command -v loginctl &> /dev/null; then
        loginctl enable-linger "$(whoami)" 2>/dev/null || true
        write_success "Lingering enabled (service runs on boot, not just login)"
    fi
}

disable_service() {
    if ! command -v systemctl &> /dev/null; then
        write_error "systemctl not found. Systemd is required for this feature."
        exit 1
    fi
    
    write_step "Disabling $SERVICE_NAME service..."
    systemctl --user stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl --user disable "$SERVICE_NAME" 2>/dev/null || true
    write_success "Service disabled"
    echo "The server will no longer auto-start."
}

if [ "$ENABLE" = true ]; then
    enable_service
elif [ "$DISABLE" = true ]; then
    disable_service
elif [ "$STATUS" = true ]; then
    show_status
elif [ "$STOP" = true ]; then
    stop_server
elif [ "$LOGS" = true ]; then
    show_logs
elif [ "$RESTART" = true ]; then
    stop_server
    sleep 1
    start_server
else
    start_server
fi
