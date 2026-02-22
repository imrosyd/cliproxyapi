#!/bin/bash
#
# CLIProxyAPI GUI Control Center for Linux/macOS
#
# Starts an HTTP management server that serves the GUI and provides API endpoints
# for controlling the CLIProxyAPI server.
#
# Usage:
#   ./gui-cliproxyapi.sh              # Start on default port 8318
#   ./gui-cliproxyapi.sh --port 9000  # Use custom port
#   ./gui-cliproxyapi.sh --no-browser # Don't open browser
#

set -e

SCRIPT_VERSION="1.2.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUI_PATH=""
BIN_DIR="$HOME/bin"
CONFIG_DIR="$HOME/.cliproxyapi"
BINARY="$BIN_DIR/cliproxyapi"
CONFIG="$CONFIG_DIR/config.yaml"
LOG_DIR="$CONFIG_DIR/logs"
API_PORT=8317

find_gui_path() {
    local candidates=(
        "$SCRIPT_DIR/../gui/index.html"
        "$(dirname "$SCRIPT_DIR")/gui/index.html"
        "$HOME/cliproxyapi/gui/index.html"
        "$HOME/.cliproxyapi/gui/index.html"
    )
    
    for path in "${candidates[@]}"; do
        if [ -f "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    return 1
}

GUI_PATH=$(find_gui_path)

PORT=8318
NO_BROWSER=false

for arg in "$@"; do
    case $arg in
        --port=*) PORT="${arg#*=}" ;;
        --port) shift; PORT="$1" ;;
        --no-browser) NO_BROWSER=true ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --port PORT   Use custom port (default: 8318)"
            echo "  --no-browser  Don't open browser automatically"
            echo "  --help        Show this help"
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

write_log() { echo "[$(date '+%H:%M:%S')] $1"; }

get_server_pid() {
    if [ -f "$CONFIG_DIR/cliproxyapi.pid" ]; then
        PID=$(cat "$CONFIG_DIR/cliproxyapi.pid")
        if kill -0 "$PID" 2>/dev/null; then
            echo "$PID"
            return
        fi
    fi
    
    PID=$(pgrep -f "cliproxyapi.*config.yaml" 2>/dev/null | head -1)
    echo "$PID"
}

get_server_status() {
    PID=$(get_server_pid)
    
    if [ -n "$PID" ]; then
        MEM=$(ps -o rss= -p "$PID" 2>/dev/null | awk '{printf "%.1f", $1/1024}')
        START=$(ps -o lstart= -p "$PID" 2>/dev/null || echo "N/A")
        
        cat << EOF
{"running":true,"pid":$PID,"memory":$MEM,"startTime":"$START","port":$API_PORT,"endpoint":"http://localhost:$API_PORT/v1"}
EOF
    else
        cat << EOF
{"running":false,"pid":null,"memory":null,"startTime":null,"port":$API_PORT,"endpoint":"http://localhost:$API_PORT/v1"}
EOF
    fi
}

start_api_server() {
    PID=$(get_server_pid)
    if [ -n "$PID" ]; then
        echo '{"success":false,"error":"Server already running (PID: '$PID')"}'
        return
    fi
    
    if [ ! -f "$BINARY" ]; then
        echo '{"success":false,"error":"Binary not found"}'
        return
    fi
    
    if [ ! -f "$CONFIG" ]; then
        echo '{"success":false,"error":"Config not found"}'
        return
    fi
    
    mkdir -p "$LOG_DIR"
    
    nohup "$BINARY" --config "$CONFIG" > "$LOG_DIR/server.log" 2>&1 &
    NEW_PID=$!
    echo $NEW_PID > "$CONFIG_DIR/cliproxyapi.pid"
    sleep 1
    
    if kill -0 "$NEW_PID" 2>/dev/null; then
        echo '{"success":true,"pid":'$NEW_PID',"message":"Server started"}'
    else
        echo '{"success":false,"error":"Server failed to start"}'
    fi
}

stop_api_server() {
    PID=$(get_server_pid)
    
    if [ -z "$PID" ]; then
        echo '{"success":false,"error":"Server not running"}'
        return
    fi
    
    kill "$PID" 2>/dev/null || true
    rm -f "$CONFIG_DIR/cliproxyapi.pid"
    echo '{"success":true,"message":"Server stopped"}'
}

restart_api_server() {
    stop_api_server > /dev/null
    sleep 1
    start_api_server
}

get_auth_status() {
    local status="{"
    local first=true
    
    for provider in gemini copilot antigravity codex claude qwen iflow kiro; do
        if ls "$CONFIG_DIR/${provider}"*.json 2>/dev/null | head -1 > /dev/null; then
            [ "$first" = false ] && status+=","
            status+="\"$provider\":true"
        else
            [ "$first" = false ] && status+=","
            status+="\"$provider\":false"
        fi
        first=false
    done
    
    status+="}"
    echo "$status"
}

get_available_models() {
    PID=$(get_server_pid)
    
    if [ -z "$PID" ]; then
        echo '{"success":false,"error":"Server not running","models":[]}'
        return
    fi
    
    MODELS=$(curl -s "http://localhost:$API_PORT/v1/models" -H "Authorization: Bearer sk-dummy" --connect-timeout 5 2>/dev/null)
    
    if [ -n "$MODELS" ]; then
        echo "$MODELS"
    else
        echo '{"success":false,"error":"Could not fetch models","models":[]}'
    fi
}

get_config_content() {
    if [ ! -f "$CONFIG" ]; then
        echo '{"success":false,"error":"Config not found","content":""}'
        return
    fi
    
    CONTENT=$(cat "$CONFIG" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    echo "{\"success\":true,\"content\":\"$CONTENT\"}"
}

handle_request() {
    local method="$1"
    local path="$2"
    local body="$3"
    
    case "$path" in
        /)
            if [ -f "$GUI_PATH" ]; then
                echo "HTTP/1.1 200 OK"
                echo "Content-Type: text/html; charset=utf-8"
                echo "Access-Control-Allow-Origin: *"
                echo ""
                cat "$GUI_PATH"
            else
                echo "HTTP/1.1 404 Not Found"
                echo "Content-Type: text/plain"
                echo ""
                echo "GUI not found"
            fi
            ;;
        /api/status)
            echo "HTTP/1.1 200 OK"
            echo "Content-Type: application/json"
            echo "Access-Control-Allow-Origin: *"
            echo ""
            get_server_status
            ;;
        /api/auth-status)
            echo "HTTP/1.1 200 OK"
            echo "Content-Type: application/json"
            echo "Access-Control-Allow-Origin: *"
            echo ""
            get_auth_status
            ;;
        /api/models)
            echo "HTTP/1.1 200 OK"
            echo "Content-Type: application/json"
            echo "Access-Control-Allow-Origin: *"
            echo ""
            get_available_models
            ;;
        /api/config)
            if [ "$method" = "GET" ]; then
                echo "HTTP/1.1 200 OK"
                echo "Content-Type: application/json"
                echo "Access-Control-Allow-Origin: *"
                echo ""
                get_config_content
            elif [ "$method" = "POST" ]; then
                CONTENT=$(echo "$body" | sed 's/.*"content":"\([^"]*\)".*/\1/' | sed 's/\\n/\n/g' | sed 's/\\"/"/g')
                echo "$CONTENT" > "$CONFIG"
                echo "HTTP/1.1 200 OK"
                echo "Content-Type: application/json"
                echo "Access-Control-Allow-Origin: *"
                echo ""
                echo '{"success":true,"message":"Config saved"}'
            fi
            ;;
        /api/start)
            echo "HTTP/1.1 200 OK"
            echo "Content-Type: application/json"
            echo "Access-Control-Allow-Origin: *"
            echo ""
            start_api_server
            ;;
        /api/stop)
            echo "HTTP/1.1 200 OK"
            echo "Content-Type: application/json"
            echo "Access-Control-Allow-Origin: *"
            echo ""
            stop_api_server
            ;;
        /api/restart)
            echo "HTTP/1.1 200 OK"
            echo "Content-Type: application/json"
            echo "Access-Control-Allow-Origin: *"
            echo ""
            restart_api_server
            ;;
        /api/stats)
            echo "HTTP/1.1 200 OK"
            echo "Content-Type: application/json"
            echo "Access-Control-Allow-Origin: *"
            echo ""
            echo '{"total":0,"success":0,"errors":0,"successRate":0,"avgLatency":0,"available":false,"message":"Stats not available"}'
            ;;
        /api/version)
            echo "HTTP/1.1 200 OK"
            echo "Content-Type: application/json"
            echo "Access-Control-Allow-Origin: *"
            echo ""
            echo "{\"scripts\":\"$SCRIPT_VERSION\"}"
            ;;
        *)
            echo "HTTP/1.1 404 Not Found"
            echo "Content-Type: application/json"
            echo "Access-Control-Allow-Origin: *"
            echo ""
            echo '{"error":"Not found"}'
            ;;
    esac
}

echo -e "${MAGENTA}============================================"
echo -e "  CLIProxyAPI+ Control Center"
echo -e "============================================${NC}"

if [ ! -f "$GUI_PATH" ]; then
    echo -e "${RED}[-] GUI not found at: $GUI_PATH${NC}"
    exit 1
fi

if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    echo -e "${RED}[-] Python is required for the GUI server${NC}"
    exit 1
fi

write_log "Management server starting on http://localhost:$PORT"
echo ""
echo -e "  ${CYAN}GUI:      http://localhost:$PORT${NC}"
echo -e "  ${CYAN}API:      http://localhost:$PORT/api/*${NC}"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

if [ "$NO_BROWSER" = false ]; then
    if command -v xdg-open &> /dev/null; then
        xdg-open "http://localhost:$PORT" &
    elif command -v open &> /dev/null; then
        open "http://localhost:$PORT" &
    fi
fi

cleanup() {
    echo ""
    write_log "Shutting down..."
    [ -n "$SERVER_PID" ] && kill $SERVER_PID 2>/dev/null
    exit 0
}
trap cleanup SIGINT SIGTERM

$PYTHON_CMD -c "
import http.server
import socketserver
import json
import os
import subprocess
import sys
import time
import threading
import datetime

PORT = $PORT
CONFIG_DIR = '$CONFIG_DIR'
BINARY = '$BINARY'
CONFIG = '$CONFIG'
GUI_PATH = '$GUI_PATH'
PID_FILE = os.path.join(CONFIG_DIR, 'cliproxyapi.pid')
STATS_FILE = os.path.join(CONFIG_DIR, 'stats.json')
LOG_FILE = os.path.join(CONFIG_DIR, 'logs', 'server.log')

# Stats management
stats_lock = threading.Lock()

def load_stats():
    try:
        if os.path.exists(STATS_FILE):
            with open(STATS_FILE, 'r') as f:
                return json.load(f)
    except:
        pass
    return {
        'total_requests': 0,
        'successful': 0,
        'failed': 0,
        'by_provider': {},
        'by_model': {},
        'latencies': [],
        'start_time': datetime.datetime.now().isoformat(),
        'last_request': None
    }

def save_stats(stats):
    try:
        with open(STATS_FILE, 'w') as f:
            json.dump(stats, f, indent=2)
    except:
        pass

def increment_stats(success=True, provider=None, model=None, latency_ms=None):
    with stats_lock:
        stats = load_stats()
        stats['total_requests'] += 1
        if success:
            stats['successful'] += 1
        else:
            stats['failed'] += 1
        if provider:
            if provider not in stats['by_provider']:
                stats['by_provider'][provider] = {'requests': 0, 'success': 0, 'failed': 0}
            stats['by_provider'][provider]['requests'] += 1
            if success:
                stats['by_provider'][provider]['success'] += 1
            else:
                stats['by_provider'][provider]['failed'] += 1
        if model:
            if model not in stats['by_model']:
                stats['by_model'][model] = {'requests': 0, 'latency_ms': []}
            stats['by_model'][model]['requests'] += 1
            if latency_ms:
                stats['by_model'][model]['latency_ms'].append(latency_ms)
                # Keep only last 100 latencies
                stats['by_model'][model]['latency_ms'] = stats['by_model'][model]['latency_ms'][-100:]
        if latency_ms:
            stats['latencies'].append(latency_ms)
            stats['latencies'] = stats['latencies'][-100:]
        stats['last_request'] = datetime.datetime.now().isoformat()
        save_stats(stats)

# Initialize stats
STATS = load_stats()
save_stats(STATS)

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass
    
    def send_json(self, data, status=200):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())
    
    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
    
    def do_GET(self):
        # Parse path without query string
        parsed_path = self.path.split('?')[0] if '?' in self.path else self.path
        
        if parsed_path == '/':
            self.serve_gui()
        elif parsed_path == '/api/status':
            self.api_status()
        elif parsed_path == '/api/auth-status':
            self.api_auth_status()
        elif parsed_path == '/api/models':
            self.api_models()
        elif parsed_path == '/api/config':
            self.api_get_config()
        elif parsed_path == '/api/stats':
            self.api_stats()
        elif parsed_path == '/api/logs':
            self.api_logs()
        elif parsed_path == '/api/version':
            self.send_json({'scripts': '$SCRIPT_VERSION'})
        elif parsed_path == '/api/management/usage':
            self.api_management_usage()
        elif parsed_path == '/api/factory-config':
            self.api_get_factory_config()
        else:
            self.send_json({'error': 'Not found'}, 404)
    
    def do_DELETE(self):
        if self.path == '/api/stats':
            self.api_stats_reset()
        else:
            self.send_json({'error': 'Not found'}, 404)
    
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode() if content_length > 0 else '{}'
        
        if self.path == '/api/start':
            self.api_start()
        elif self.path == '/api/stop':
            self.api_stop()
        elif self.path == '/api/restart':
            self.api_restart()
        elif self.path == '/api/config':
            self.api_save_config(body)
        elif self.path.startswith('/api/oauth/'):
            provider = self.path.split('/')[-1]
            self.api_oauth(provider)
        elif self.path == '/api/proxy':
            self.api_proxy(body)
        elif self.path == '/api/factory-config/add':
            self.api_factory_config_add(body)
        elif self.path == '/api/factory-config/remove':
            self.api_factory_config_remove(body)
        else:
            self.send_json({'error': 'Not found'}, 404)
    
    def api_proxy(self, body):
        '''Proxy a request to the API server and track stats'''
        import urllib.request
        import urllib.error
        
        try:
            data = json.loads(body)
            target_path = data.get('path', '/v1/chat/completions')
            method = data.get('method', 'POST')
            payload = data.get('body', {})
            model = payload.get('model', '') if isinstance(payload, dict) else ''
            
            url = f'http://localhost:8317{target_path}'
            
            start_time = time.time()
            
            req = urllib.request.Request(url, method=method)
            req.add_header('Content-Type', 'application/json')
            req.add_header('Authorization', 'Bearer sk-dummy')
            
            if method in ['POST', 'PUT', 'PATCH']:
                req_data = json.dumps(payload).encode()
            else:
                req_data = None
            
            try:
                with urllib.request.urlopen(req, req_data, timeout=120) as resp:
                    response_data = resp.read().decode()
                    latency_ms = (time.time() - start_time) * 1000
                    
                    # Detect provider from model name
                    provider = None
                    if model:
                        if 'gemini' in model.lower():
                            provider = 'gemini'
                        elif 'claude' in model.lower() and 'kiro' in model.lower():
                            provider = 'kiro'
                        elif 'claude' in model.lower():
                            provider = 'claude'
                        elif 'gpt' in model.lower() or 'codex' in model.lower():
                            provider = 'openai'
                        elif 'qwen' in model.lower():
                            provider = 'qwen'
                        elif 'grok' in model.lower():
                            provider = 'grok'
                    
                    increment_stats(success=True, provider=provider, model=model, latency_ms=latency_ms)
                    
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    self.wfile.write(response_data.encode())
                    
            except urllib.error.HTTPError as e:
                latency_ms = (time.time() - start_time) * 1000
                increment_stats(success=False, provider=None, model=model, latency_ms=latency_ms)
                
                self.send_response(e.code)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(e.read())
                
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)}, 500)
    
    def serve_gui(self):
        if os.path.exists(GUI_PATH):
            with open(GUI_PATH, 'r') as f:
                content = f.read()
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(content.encode())
        else:
            self.send_json({'error': 'GUI not found'}, 404)
    
    def get_pid(self):
        # First, check if port 8317 is actually listening
        try:
            import socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            result = sock.connect_ex(('localhost', 8317))
            sock.close()
            if result != 0:
                # Port not listening, clean up stale pid file
                if os.path.exists(PID_FILE):
                    os.remove(PID_FILE)
                return None
        except:
            pass
        
        # Check pid file
        if os.path.exists(PID_FILE):
            try:
                with open(PID_FILE) as f:
                    pid = int(f.read().strip())
                os.kill(pid, 0)
                return pid
            except:
                if os.path.exists(PID_FILE):
                    os.remove(PID_FILE)
                pass
        
        # Find with pgrep
        try:
            result = subprocess.run(['pgrep', '-f', 'cliproxyapi.*config'], capture_output=True, text=True)
            if result.returncode == 0 and result.stdout.strip():
                pids = result.stdout.strip().split('\\n')
                for pid_str in pids:
                    if pid_str:
                        try:
                            pid = int(pid_str)
                            os.kill(pid, 0)
                            with open(PID_FILE, 'w') as pf:
                                pf.write(str(pid))
                            return pid
                        except:
                            pass
        except:
            pass
        return None
    
    def api_status(self):
        pid = self.get_pid()
        if pid:
            self.send_json({'running': True, 'pid': pid, 'port': 8317, 'endpoint': 'http://localhost:8317/v1'})
        else:
            self.send_json({'running': False, 'pid': None, 'port': 8317, 'endpoint': 'http://localhost:8317/v1'})
    
    def api_auth_status(self):
        providers = ['gemini', 'copilot', 'antigravity', 'codex', 'claude', 'qwen', 'iflow', 'kiro']
        status = {}
        for p in providers:
            files = [f for f in os.listdir(CONFIG_DIR) if f.startswith(p) and f.endswith('.json')]
            status[p] = len(files) > 0
        self.send_json(status)
    
    def api_models(self):
        try:
            import urllib.request
            req = urllib.request.Request('http://localhost:8317/v1/models')
            req.add_header('Authorization', 'Bearer sk-dummy')
            with urllib.request.urlopen(req, timeout=5) as resp:
                data = json.loads(resp.read().decode())
                self.send_json(data)
        except:
            self.send_json({'success': False, 'error': 'Server not running', 'models': []})
    
    def api_management_usage(self):
        '''Proxy to the upstream Management API for usage statistics'''
        try:
            import urllib.request
            req = urllib.request.Request('http://localhost:8317/v0/management/usage')
            # Try without auth first (localhost bypass may work)
            try:
                with urllib.request.urlopen(req, timeout=5) as resp:
                    data = json.loads(resp.read().decode())
                    self.send_json(data)
                    return
            except:
                pass
            # If that fails, try with dummy key
            req = urllib.request.Request('http://localhost:8317/v0/management/usage')
            req.add_header('Authorization', 'Bearer sk-dummy')
            try:
                with urllib.request.urlopen(req, timeout=5) as resp:
                    data = json.loads(resp.read().decode())
                    self.send_json(data)
                    return
            except:
                pass
            self.send_json({'available': False, 'error': 'Management API not available. Enable usage-statistics-enabled in config.yaml'})
        except Exception as e:
            self.send_json({'available': False, 'error': str(e)})
    
    def api_get_factory_config(self):
        '''Get Factory config from ~/.factory/config.json'''
        factory_path = os.path.expanduser('~/.factory/config.json')
        try:
            if os.path.exists(factory_path):
                with open(factory_path, 'r') as f:
                    data = json.load(f)
                models = data.get('models', [])
                self.send_json({'success': True, 'models': models, 'count': len(models)})
            else:
                self.send_json({'success': True, 'models': [], 'count': 0})
        except Exception as e:
            self.send_json({'success': False, 'error': str(e), 'models': [], 'count': 0})
    
    def api_factory_config_add(self, body):
        '''Add models to Factory config'''
        factory_path = os.path.expanduser('~/.factory/config.json')
        try:
            data = json.loads(body)
            models_to_add = data.get('models', [])
            display_names = data.get('displayNames', {})
            
            # Load existing
            existing = {'models': []}
            if os.path.exists(factory_path):
                with open(factory_path, 'r') as f:
                    existing = json.load(f)
            
            current_models = [m.get('id', m) if isinstance(m, dict) else m for m in existing.get('models', [])]
            added = 0
            for model in models_to_add:
                if model not in current_models:
                    entry = {'id': model}
                    if model in display_names:
                        entry['displayName'] = display_names[model]
                    existing.setdefault('models', []).append(entry)
                    added += 1
            
            os.makedirs(os.path.dirname(factory_path), exist_ok=True)
            with open(factory_path, 'w') as f:
                json.dump(existing, f, indent=2)
            
            self.send_json({'success': True, 'added': added, 'total': len(existing.get('models', []))})
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)})
    
    def api_factory_config_remove(self, body):
        '''Remove models from Factory config'''
        factory_path = os.path.expanduser('~/.factory/config.json')
        try:
            data = json.loads(body)
            remove_all = data.get('all', False)
            
            if remove_all:
                if os.path.exists(factory_path):
                    with open(factory_path, 'r') as f:
                        existing = json.load(f)
                    existing['models'] = []
                    with open(factory_path, 'w') as f:
                        json.dump(existing, f, indent=2)
                self.send_json({'success': True, 'removed': 'all', 'total': 0})
                return
            
            models_to_remove = set(data.get('models', []))
            if os.path.exists(factory_path):
                with open(factory_path, 'r') as f:
                    existing = json.load(f)
                before = len(existing.get('models', []))
                existing['models'] = [m for m in existing.get('models', []) if (m.get('id', m) if isinstance(m, dict) else m) not in models_to_remove]
                after = len(existing['models'])
                with open(factory_path, 'w') as f:
                    json.dump(existing, f, indent=2)
                self.send_json({'success': True, 'removed': before - after, 'total': after})
            else:
                self.send_json({'success': True, 'removed': 0, 'total': 0})
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)})
    
    def api_stats(self):
        stats = load_stats()
        total = stats['total_requests']
        successful = stats['successful']
        failed = stats['failed']
        success_rate = (successful / total * 100) if total > 0 else 0
        avg_latency = sum(stats['latencies']) / len(stats['latencies']) if stats['latencies'] else 0
        
        result = {
            'total': total,
            'successful': successful,
            'failed': failed,
            'successRate': round(success_rate, 1),
            'avgLatency': round(avg_latency, 0),
            'available': True,
            'by_provider': stats['by_provider'],
            'by_model': stats['by_model'],
            'start_time': stats['start_time'],
            'last_request': stats['last_request']
        }
        self.send_json(result)
    
    def api_stats_reset(self):
        global STATS
        STATS = {
            'total_requests': 0,
            'successful': 0,
            'failed': 0,
            'by_provider': {},
            'by_model': {},
            'latencies': [],
            'start_time': datetime.datetime.now().isoformat(),
            'last_request': None
        }
        save_stats(STATS)
        self.send_json({'success': True, 'message': 'Stats reset'})
    
    def api_logs(self):
        lines = 100
        if '?' in self.path:
            params = self.path.split('?')[1].split('&')
            for p in params:
                if p.startswith('lines='):
                    try:
                        lines = int(p.split('=')[1])
                    except:
                        pass
        
        log_file = LOG_FILE
        if os.path.exists(log_file):
            try:
                with open(log_file, 'r') as f:
                    all_lines = f.readlines()
                    recent = all_lines[-lines:] if len(all_lines) > lines else all_lines
                    self.send_json({
                        'success': True,
                        'lines': [l.strip() for l in recent],
                        'total': len(all_lines)
                    })
            except Exception as e:
                self.send_json({'success': False, 'error': str(e)})
        else:
            self.send_json({'success': True, 'lines': [], 'total': 0})
    
    def api_get_config(self):
        if os.path.exists(CONFIG):
            with open(CONFIG) as f:
                content = f.read()
            self.send_json({'success': True, 'content': content})
        else:
            self.send_json({'success': False, 'error': 'Config not found'})
    
    def api_save_config(self, body):
        try:
            data = json.loads(body)
            with open(CONFIG, 'w') as f:
                f.write(data.get('content', ''))
            self.send_json({'success': True, 'message': 'Config saved'})
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)})
    
    def api_start(self):
        pid = self.get_pid()
        if pid:
            self.send_json({'success': False, 'error': 'Server already running'})
            return
        if not os.path.exists(BINARY):
            self.send_json({'success': False, 'error': 'Binary not found'})
            return
        
        # Create logs directory if needed
        os.makedirs(os.path.join(CONFIG_DIR, 'logs'), exist_ok=True)
        
        # Start the server
        log_file = os.path.join(CONFIG_DIR, 'logs', 'server.log')
        proc = subprocess.Popen(
            [BINARY, '--config', CONFIG],
            stdout=open(log_file, 'w'),
            stderr=subprocess.STDOUT,
            start_new_session=True
        )
        
        # Save PID
        with open(PID_FILE, 'w') as f:
            f.write(str(proc.pid))
        
        # Wait for server to start
        time.sleep(2)
        
        # Verify it's running
        try:
            os.kill(proc.pid, 0)
            # Also check if port is listening
            import socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            result = sock.connect_ex(('localhost', 8317))
            sock.close()
            if result == 0:
                self.send_json({'success': True, 'pid': proc.pid})
            else:
                # Server process exists but not listening yet, wait more
                time.sleep(2)
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                result = sock.connect_ex(('localhost', 8317))
                sock.close()
                if result == 0:
                    self.send_json({'success': True, 'pid': proc.pid})
                else:
                    self.send_json({'success': False, 'error': 'Server started but not responding on port 8317'})
        except ProcessLookupError:
            self.send_json({'success': False, 'error': 'Server process died'})
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)})
    
    def api_stop(self):
        # Kill only the server process (not the GUI process)
        try:
            # Kill by PID file first
            if os.path.exists(PID_FILE):
                try:
                    with open(PID_FILE) as f:
                        pid = int(f.read().strip())
                    os.kill(pid, 15)  # SIGTERM
                    time.sleep(1)
                    # Force kill if still running
                    try:
                        os.kill(pid, 0)
                        os.kill(pid, 9)  # SIGKILL
                    except:
                        pass
                except:
                    pass
                os.remove(PID_FILE)
            
            # Also kill any orphaned server processes (but not GUI)
            # Use exact match to avoid killing GUI
            subprocess.run(['pkill', '-x', 'cliproxyapi'], capture_output=True)
            
            self.send_json({'success': True, 'message': 'Server stopped'})
        except Exception as e:
            self.send_json({'success': False, 'error': str(e)})
    
    def api_restart(self):
        self.api_stop()
        time.sleep(2)
        self.api_start()
    
    def api_oauth(self, provider):
        flags = {
            'gemini': '--login',
            'copilot': '--github-copilot-login',
            'antigravity': '--antigravity-login',
            'codex': '--codex-login',
            'claude': '--claude-login',
            'qwen': '--qwen-login',
            'iflow': '--iflow-login',
            'kiro': '--kiro-aws-login'
        }
        flag = flags.get(provider.lower())
        if not flag:
            self.send_json({'success': False, 'error': 'Unknown provider'})
            return
        subprocess.Popen([BINARY, '--config', CONFIG, flag])
        self.send_json({'success': True, 'message': f'OAuth started for {provider}'})

with socketserver.TCPServer(('', PORT), Handler) as httpd:
    print(f'Server running on port {PORT}')
    httpd.serve_forever()
" &
SERVER_PID=$!

wait $SERVER_PID
