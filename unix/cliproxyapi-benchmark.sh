#!/bin/bash
#
# CLIProxyAPI Latency Benchmark
#
# Tests response latency for each available model through the proxy.
# Results are ranked from fastest to slowest with color indicators.
#
# Usage:
#   ./cliproxyapi-benchmark.sh              # Benchmark all models
#   ./cliproxyapi-benchmark.sh --json       # Output JSON only
#   ./cliproxyapi-benchmark.sh --top 5      # Show top 5 fastest
#

set -e

PORT=8317
BASE_URL="http://localhost:$PORT"
CONFIG_DIR="$HOME/.cliproxyapi"
BENCHMARK_FILE="$CONFIG_DIR/benchmark.json"
OUTPUT_JSON=false
TOP_N=0
TIMEOUT=30

for arg in "$@"; do
    case $arg in
        --json) OUTPUT_JSON=true ;;
        --top)
            shift
            TOP_N="${2:-5}"
            ;;
        --port)
            shift
            PORT="${2:-8317}"
            BASE_URL="http://localhost:$PORT"
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --json       Output results as JSON only"
            echo "  --top N      Show only top N fastest models"
            echo "  --port PORT  Use custom port (default: 8317)"
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
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

write_step() { echo -e "\n${CYAN}[*] $1${NC}"; }
write_success() { echo -e "${GREEN}[+] $1${NC}"; }
write_warning() { echo -e "${YELLOW}[!] $1${NC}"; }
write_error() { echo -e "${RED}[-] $1${NC}"; }

if ! command -v curl &> /dev/null; then
    write_error "curl is required but not installed."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    HAS_JQ=false
else
    HAS_JQ=true
fi

check_server() {
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/v1/models" --connect-timeout 3 2>/dev/null || echo "000")
    if [ "$RESPONSE" != "200" ]; then
        write_error "Server not responding at $BASE_URL"
        echo "  Make sure CLIProxyAPI is running: start-cliproxyapi -b"
        exit 1
    fi
}

get_models() {
    MODELS_RESPONSE=$(curl -s "$BASE_URL/v1/models" \
        -H "Authorization: Bearer sk-dummy" \
        --connect-timeout 5 2>/dev/null)

    if [ "$HAS_JQ" = true ]; then
        echo "$MODELS_RESPONSE" | jq -r '.data[].id' 2>/dev/null
    else
        echo "$MODELS_RESPONSE" | grep -oP '"id"\s*:\s*"\K[^"]+' 2>/dev/null
    fi
}

benchmark_model() {
    local model="$1"

    local start_time end_time elapsed http_code response

    start_time=$(date +%s%N 2>/dev/null || python3 -c "import time; print(int(time.time()*1e9))" 2>/dev/null || echo "0")

    response=$(curl -s -w "\n%{http_code}\n%{time_total}" \
        "$BASE_URL/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer sk-dummy" \
        -d "{
            \"model\": \"$model\",
            \"messages\": [{\"role\": \"user\", \"content\": \"Hi\"}],
            \"max_tokens\": 5
        }" \
        --connect-timeout 5 \
        --max-time $TIMEOUT 2>/dev/null)

    http_code=$(echo "$response" | tail -2 | head -1)
    local time_total=$(echo "$response" | tail -1)

    local latency_ms=$(echo "$time_total" | awk '{printf "%.0f", $1 * 1000}')

    if [ "$http_code" = "200" ]; then
        echo "OK|$latency_ms"
    else
        echo "FAIL|$latency_ms|HTTP$http_code"
    fi
}

colorize_latency() {
    local ms=$1
    if [ "$ms" -lt 2000 ]; then
        echo -e "${GREEN}${ms}ms${NC}"
    elif [ "$ms" -lt 5000 ]; then
        echo -e "${YELLOW}${ms}ms${NC}"
    else
        echo -e "${RED}${ms}ms${NC}"
    fi
}

latency_bar() {
    local ms=$1
    local max_ms=${2:-10000}
    local max_width=30

    local width=$((ms * max_width / max_ms))
    [ "$width" -lt 1 ] && width=1
    [ "$width" -gt "$max_width" ] && width=$max_width

    local bar=""
    for ((i = 0; i < width; i++)); do
        bar="${bar}█"
    done

    if [ "$ms" -lt 2000 ]; then
        echo -e "${GREEN}${bar}${NC}"
    elif [ "$ms" -lt 5000 ]; then
        echo -e "${YELLOW}${bar}${NC}"
    else
        echo -e "${RED}${bar}${NC}"
    fi
}

if [ "$OUTPUT_JSON" = false ]; then
    echo -e "${MAGENTA}${BOLD}=============================================="
    echo -e "  CLIProxyAPI Latency Benchmark"
    echo -e "==============================================${NC}"
fi

check_server

if [ "$OUTPUT_JSON" = false ]; then
    write_step "Fetching available models..."
fi

MODELS=$(get_models)
MODEL_COUNT=$(echo "$MODELS" | wc -l)

if [ -z "$MODELS" ] || [ "$MODEL_COUNT" -eq 0 ]; then
    write_error "No models found. Make sure you're logged in to at least one provider."
    exit 1
fi

if [ "$OUTPUT_JSON" = false ]; then
    write_success "Found $MODEL_COUNT models"
    write_step "Running benchmark (this may take a while)..."
    echo ""
fi

RESULTS=()
CURRENT=0

while IFS= read -r model; do
    [ -z "$model" ] && continue
    CURRENT=$((CURRENT + 1))

    if [ "$OUTPUT_JSON" = false ]; then
        printf "  ${DIM}[%d/%d]${NC} Testing ${CYAN}%-40s${NC} " "$CURRENT" "$MODEL_COUNT" "$model"
    fi

    RESULT=$(benchmark_model "$model")
    STATUS=$(echo "$RESULT" | cut -d'|' -f1)
    LATENCY=$(echo "$RESULT" | cut -d'|' -f2)
    ERROR=$(echo "$RESULT" | cut -d'|' -f3)

    if [ "$STATUS" = "OK" ]; then
        RESULTS+=("$LATENCY|$model|OK")
        if [ "$OUTPUT_JSON" = false ]; then
            echo -e "$(colorize_latency "$LATENCY")"
        fi
    else
        RESULTS+=("999999|$model|FAIL|$ERROR")
        if [ "$OUTPUT_JSON" = false ]; then
            echo -e "${RED}FAILED${NC} ${DIM}($ERROR)${NC}"
        fi
    fi
done <<< "$MODELS"

IFS=$'\n' SORTED=($(for r in "${RESULTS[@]}"; do echo "$r"; done | sort -t'|' -k1 -n))
unset IFS

if [ "$TOP_N" -gt 0 ]; then
    SORTED=("${SORTED[@]:0:$TOP_N}")
fi

MAX_LATENCY=1
for entry in "${SORTED[@]}"; do
    lat=$(echo "$entry" | cut -d'|' -f1)
    if [ "$lat" != "999999" ] && [ "$lat" -gt "$MAX_LATENCY" ]; then
        MAX_LATENCY=$lat
    fi
done

if [ "$OUTPUT_JSON" = false ]; then
    echo ""
    echo -e "${MAGENTA}${BOLD}=============================================="
    echo -e "  Results (Fastest → Slowest)"
    echo -e "==============================================${NC}"
    echo ""

    printf "  ${BOLD}%-3s  %-35s  %-10s  %s${NC}\n" "#" "MODEL" "LATENCY" "GRAPH"
    printf "  ${DIM}%-3s  %-35s  %-10s  %s${NC}\n" "---" "-----------------------------------" "----------" "------------------------------"

    RANK=0
    for entry in "${SORTED[@]}"; do
        RANK=$((RANK + 1))
        LATENCY=$(echo "$entry" | cut -d'|' -f1)
        MODEL=$(echo "$entry" | cut -d'|' -f2)
        STATUS=$(echo "$entry" | cut -d'|' -f3)

        if [ "$STATUS" = "OK" ]; then
            COLORED_LAT=$(colorize_latency "$LATENCY")
            BAR=$(latency_bar "$LATENCY" "$MAX_LATENCY")

            if [ "$RANK" -eq 1 ]; then
                printf "  ${GREEN}${BOLD}%-3s${NC}  ${BOLD}%-35s${NC}  %-10s  %s ${GREEN}⚡ FASTEST${NC}\n" "$RANK" "$MODEL" "$COLORED_LAT" "$BAR"
            else
                printf "  %-3s  %-35s  %-10s  %s\n" "$RANK" "$MODEL" "$COLORED_LAT" "$BAR"
            fi
        else
            ERROR=$(echo "$entry" | cut -d'|' -f4)
            printf "  %-3s  %-35s  ${RED}%-10s${NC}  ${DIM}%s${NC}\n" "$RANK" "$MODEL" "FAILED" "$ERROR"
        fi
    done

    echo ""
    echo -e "${DIM}  Legend: ${GREEN}█${NC}${DIM} < 2s  ${YELLOW}█${NC}${DIM} 2-5s  ${RED}█${NC}${DIM} > 5s${NC}"
fi

mkdir -p "$CONFIG_DIR"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")

JSON_RESULTS="["
FIRST=true
for entry in "${SORTED[@]}"; do
    LATENCY=$(echo "$entry" | cut -d'|' -f1)
    MODEL=$(echo "$entry" | cut -d'|' -f2)
    STATUS=$(echo "$entry" | cut -d'|' -f3)

    [ "$FIRST" = true ] && FIRST=false || JSON_RESULTS+=","

    if [ "$STATUS" = "OK" ]; then
        JSON_RESULTS+="{\"model\":\"$MODEL\",\"latency_ms\":$LATENCY,\"status\":\"ok\"}"
    else
        ERROR=$(echo "$entry" | cut -d'|' -f4)
        JSON_RESULTS+="{\"model\":\"$MODEL\",\"latency_ms\":null,\"status\":\"failed\",\"error\":\"$ERROR\"}"
    fi
done
JSON_RESULTS+="]"

BENCHMARK_JSON="{\"timestamp\":\"$TIMESTAMP\",\"server\":\"$BASE_URL\",\"results\":$JSON_RESULTS}"

echo "$BENCHMARK_JSON" > "$BENCHMARK_FILE"

if [ "$OUTPUT_JSON" = true ]; then
    if [ "$HAS_JQ" = true ]; then
        echo "$BENCHMARK_JSON" | jq .
    else
        echo "$BENCHMARK_JSON"
    fi
else
    echo ""
    write_success "Results saved to $BENCHMARK_FILE"
    echo ""
    echo -e "${MAGENTA}==============================================${NC}"
fi
