#!/usr/bin/env bash
# nexus-metrics.sh - Performance metrics collection and analysis
# Usage: ./nexus-metrics.sh [--interval N] [--duration M] [--export FILE]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default values
INTERVAL=5  # seconds between samples
DURATION=60  # total duration in seconds
EXPORT_FILE=""
CONTINUOUS=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --interval|-i)
            INTERVAL="$2"
            shift 2
            ;;
        --duration|-d)
            DURATION="$2"
            shift 2
            ;;
        --export|-e)
            EXPORT_FILE="$2"
            shift 2
            ;;
        --continuous|-c)
            CONTINUOUS=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --interval N, -i N    Sample interval in seconds (default: 5)"
            echo "  --duration M, -d M    Total duration in seconds (default: 60)"
            echo "  --export FILE, -e     Export metrics to CSV file"
            echo "  --continuous, -c      Run continuously (Ctrl+C to stop)"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 --interval 10 --duration 300"
            echo "  $0 --export /tmp/metrics.csv"
            echo "  $0 --continuous"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           NEXUS PERFORMANCE METRICS                      ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

if [ "$CONTINUOUS" = true ]; then
    echo "Mode: Continuous monitoring (Ctrl+C to stop)"
else
    echo "Interval: ${INTERVAL}s"
    echo "Duration: ${DURATION}s"
    echo "Samples: $((DURATION / INTERVAL))"
fi

if [ -n "$EXPORT_FILE" ]; then
    echo "Export: $EXPORT_FILE"
fi

echo ""

# Initialize export file with headers
if [ -n "$EXPORT_FILE" ]; then
    echo "timestamp,cpu_usage,mem_used_mb,mem_percent,disk_usage_percent,cpu_temp,load_avg_1m,docker_cpu_n8n,docker_mem_n8n,docker_cpu_postgres,docker_mem_postgres,docker_cpu_redis,docker_mem_redis" > "$EXPORT_FILE"
fi

# Initialize metrics tracking
SAMPLE_COUNT=0
TOTAL_CPU=0
TOTAL_MEM=0
MAX_CPU=0
MAX_MEM=0
MIN_CPU=100
MIN_MEM=100

# Function to collect single metric sample
collect_sample() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # System metrics
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    local mem_info=$(free -m | awk 'NR==2{printf "%s,%s", $3,$3*100/$2}')
    local mem_used=$(echo "$mem_info" | cut -d',' -f1)
    local mem_percent=$(echo "$mem_info" | cut -d',' -f2 | cut -d'.' -f1)
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    local cpu_temp=$(vcgencmd measure_temp 2>/dev/null | grep -oP '\d+\.\d+' || echo "N/A")
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')

    # Docker container metrics
    local docker_stats=$(docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}}" 2>/dev/null | grep "nexus-")

    local n8n_cpu=$(echo "$docker_stats" | grep "nexus-n8n" | cut -d',' -f2 | sed 's/%//' || echo "0")
    local n8n_mem=$(echo "$docker_stats" | grep "nexus-n8n" | cut -d',' -f3 | awk '{print $1}' | sed 's/MiB//' || echo "0")

    local postgres_cpu=$(echo "$docker_stats" | grep "nexus-postgres" | cut -d',' -f2 | sed 's/%//' || echo "0")
    local postgres_mem=$(echo "$docker_stats" | grep "nexus-postgres" | cut -d',' -f3 | awk '{print $1}' | sed 's/MiB//' || echo "0")

    local redis_cpu=$(echo "$docker_stats" | grep "nexus-redis" | cut -d',' -f2 | sed 's/%//' || echo "0")
    local redis_mem=$(echo "$docker_stats" | grep "nexus-redis" | cut -d',' -f3 | awk '{print $1}' | sed 's/MiB//' || echo "0")

    # Update running statistics
    ((SAMPLE_COUNT++))
    TOTAL_CPU=$(echo "$TOTAL_CPU + $cpu_usage" | bc -l)
    TOTAL_MEM=$(echo "$TOTAL_MEM + $mem_percent" | bc -l)

    # Track min/max
    if (( $(echo "$cpu_usage > $MAX_CPU" | bc -l) )); then
        MAX_CPU=$cpu_usage
    fi
    if (( $(echo "$cpu_usage < $MIN_CPU" | bc -l) )); then
        MIN_CPU=$cpu_usage
    fi
    if (( $(echo "$mem_percent > $MAX_MEM" | bc -l) )); then
        MAX_MEM=$mem_percent
    fi
    if (( $(echo "$mem_percent < $MIN_MEM" | bc -l) )); then
        MIN_MEM=$mem_percent
    fi

    # Display current metrics
    echo "[$timestamp]"
    printf "System: CPU: %5.1f%% | Mem: %6dMB (%2d%%) | Disk: %2d%% | Temp: %s°C | Load: %s\n" \
        "$cpu_usage" "$mem_used" "$mem_percent" "$disk_usage" "$cpu_temp" "$load_avg"

    printf "n8n:      CPU: %5.1f%% | Mem: %6.1fMB\n" "$n8n_cpu" "$n8n_mem"
    printf "postgres: CPU: %5.1f%% | Mem: %6.1fMB\n" "$postgres_cpu" "$postgres_mem"
    printf "redis:    CPU: %5.1f%% | Mem: %6.1fMB\n" "$redis_cpu" "$redis_mem"
    echo ""

    # Export to CSV if specified
    if [ -n "$EXPORT_FILE" ]; then
        echo "$timestamp,$cpu_usage,$mem_used,$mem_percent,$disk_usage,$cpu_temp,$load_avg,$n8n_cpu,$n8n_mem,$postgres_cpu,$postgres_mem,$redis_cpu,$redis_mem" >> "$EXPORT_FILE"
    fi
}

# Function to display statistics
display_statistics() {
    if [ $SAMPLE_COUNT -eq 0 ]; then
        return
    fi

    AVG_CPU=$(echo "scale=1; $TOTAL_CPU / $SAMPLE_COUNT" | bc -l)
    AVG_MEM=$(echo "scale=1; $TOTAL_MEM / $SAMPLE_COUNT" | bc -l)

    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                  STATISTICS SUMMARY                      ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""

    echo "CPU Usage:"
    printf "  Average: %.1f%%\n" "$AVG_CPU"
    printf "  Min:     %.1f%%\n" "$MIN_CPU"
    printf "  Max:     %.1f%%\n" "$MAX_CPU"

    echo ""
    echo "Memory Usage:"
    printf "  Average: %.1f%%\n" "$AVG_MEM"
    printf "  Min:     %.1f%%\n" "$MIN_MEM"
    printf "  Max:     %.1f%%\n" "$MAX_MEM"

    echo ""
    echo "Samples: $SAMPLE_COUNT"
    echo "Duration: $((SAMPLE_COUNT * INTERVAL))s"

    # Performance assessment
    echo ""
    echo "Performance Assessment:"

    if (( $(echo "$AVG_CPU < 50" | bc -l) )); then
        echo -e "  CPU: ${GREEN}✓ Normal (avg: ${AVG_CPU}%)${NC}"
    elif (( $(echo "$AVG_CPU < 80" | bc -l) )); then
        echo -e "  CPU: ${YELLOW}⚠ Elevated (avg: ${AVG_CPU}%)${NC}"
    else
        echo -e "  CPU: ${RED}✗ High (avg: ${AVG_CPU}%)${NC}"
    fi

    if (( $(echo "$AVG_MEM < 70" | bc -l) )); then
        echo -e "  Memory: ${GREEN}✓ Normal (avg: ${AVG_MEM}%)${NC}"
    elif (( $(echo "$AVG_MEM < 85" | bc -l) )); then
        echo -e "  Memory: ${YELLOW}⚠ Elevated (avg: ${AVG_MEM}%)${NC}"
    else
        echo -e "  Memory: ${RED}✗ High (avg: ${AVG_MEM}%)${NC}"
    fi

    # Check for temperature (Raspberry Pi)
    CURRENT_TEMP=$(vcgencmd measure_temp 2>/dev/null | grep -oP '\d+\.\d+' || echo "0")
    if (( $(echo "$CURRENT_TEMP > 0 && $CURRENT_TEMP < 60" | bc -l) )); then
        echo -e "  Temperature: ${GREEN}✓ Normal (${CURRENT_TEMP}°C)${NC}"
    elif (( $(echo "$CURRENT_TEMP >= 60 && $CURRENT_TEMP < 70" | bc -l) )); then
        echo -e "  Temperature: ${YELLOW}⚠ Warm (${CURRENT_TEMP}°C)${NC}"
    elif (( $(echo "$CURRENT_TEMP >= 70" | bc -l) )); then
        echo -e "  Temperature: ${RED}✗ Hot (${CURRENT_TEMP}°C)${NC}"
    fi

    # Recommendations
    echo ""
    echo "Recommendations:"

    if (( $(echo "$MAX_CPU > 90" | bc -l) )); then
        echo "  • High CPU spikes detected - investigate heavy processes"
    fi

    if (( $(echo "$MAX_MEM > 90" | bc -l) )); then
        echo "  • High memory usage - consider adding swap or reducing container limits"
    fi

    if (( $(echo "$CURRENT_TEMP > 70" | bc -l) )); then
        echo "  • High temperature - improve cooling or reduce workload"
    fi

    if [ -n "$EXPORT_FILE" ]; then
        echo "  • Review detailed metrics: cat $EXPORT_FILE"
        echo "  • Visualize data: Import CSV into spreadsheet software"
    fi
}

# Trap Ctrl+C for continuous mode
trap 'echo ""; echo "Stopping metrics collection..."; display_statistics; exit 0' INT TERM

# Main collection loop
echo -e "${BLUE}━━━ COLLECTING METRICS ━━━${NC}"
echo ""

if [ "$CONTINUOUS" = true ]; then
    # Continuous mode
    while true; do
        collect_sample
        sleep "$INTERVAL"
    done
else
    # Fixed duration mode
    SAMPLES=$((DURATION / INTERVAL))

    for ((i=1; i<=SAMPLES; i++)); do
        collect_sample
        echo "Progress: $i/$SAMPLES"
        echo ""

        if [ $i -lt $SAMPLES ]; then
            sleep "$INTERVAL"
        fi
    done

    display_statistics
fi

if [ -n "$EXPORT_FILE" ]; then
    echo ""
    echo -e "${GREEN}✓ Metrics exported to: $EXPORT_FILE${NC}"
fi
