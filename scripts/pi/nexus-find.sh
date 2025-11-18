#!/usr/bin/env bash
# nexus-find.sh - Smart file finder for Nexus project
# Usage: ./nexus-find.sh [query] [--type TYPE] [--path PATH] [--recent]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default values
QUERY=""
TYPE=""
SEARCH_PATH="/srv"
RECENT_ONLY=false
MAX_RESULTS=50

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --type|-t)
            TYPE="$2"
            shift 2
            ;;
        --path|-p)
            SEARCH_PATH="$2"
            shift 2
            ;;
        --recent|-r)
            RECENT_ONLY=true
            shift
            ;;
        --max)
            MAX_RESULTS="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [query] [options]"
            echo ""
            echo "Options:"
            echo "  --type TYPE, -t TYPE    File type (script, config, image, template, output, log)"
            echo "  --path PATH, -p PATH    Search path (default: /srv)"
            echo "  --recent, -r            Only show files modified in last 7 days"
            echo "  --max N                 Maximum results to show (default: 50)"
            echo ""
            echo "Examples:"
            echo "  $0 carousel.py"
            echo "  $0 'slide_*' --type image"
            echo "  $0 --type output --recent"
            echo "  $0 'docker-compose' --path /srv/docker"
            exit 0
            ;;
        *)
            QUERY="$1"
            shift
            ;;
    esac
done

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              NEXUS FILE FINDER                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Build find command based on parameters
build_find_command() {
    local cmd="find $SEARCH_PATH"

    # Add type filter
    case "$TYPE" in
        script)
            cmd="$cmd -type f \( -name '*.sh' -o -name '*.py' -o -name '*.js' \)"
            ;;
        config)
            cmd="$cmd -type f \( -name '*.yml' -o -name '*.yaml' -o -name '*.json' -o -name '*.conf' -o -name '*.env' \)"
            ;;
        image)
            cmd="$cmd -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.gif' \)"
            ;;
        template)
            cmd="$cmd -type f -path '*/templates/*'"
            ;;
        output)
            cmd="$cmd -type f -path '*/outputs/*'"
            ;;
        log)
            cmd="$cmd -type f \( -name '*.log' -o -path '*/logs/*' \)"
            ;;
        *)
            cmd="$cmd -type f"
            ;;
    esac

    # Add name filter if query provided
    if [ -n "$QUERY" ]; then
        cmd="$cmd -name '$QUERY'"
    fi

    # Add recent filter
    if [ "$RECENT_ONLY" = true ]; then
        cmd="$cmd -mtime -7"
    fi

    # Add limits
    cmd="$cmd 2>/dev/null"

    echo "$cmd"
}

# Execute search
echo "Searching in: $SEARCH_PATH"
if [ -n "$TYPE" ]; then
    echo "File type: $TYPE"
fi
if [ -n "$QUERY" ]; then
    echo "Query: $QUERY"
fi
if [ "$RECENT_ONLY" = true ]; then
    echo "Filter: Modified in last 7 days"
fi
echo ""

FIND_CMD=$(build_find_command)
RESULTS=$(eval "$FIND_CMD" | head -n "$MAX_RESULTS")

if [ -z "$RESULTS" ]; then
    echo -e "${YELLOW}No files found matching your criteria${NC}"
    echo ""
    echo "Tips:"
    echo "  • Try a broader search pattern (use wildcards *)"
    echo "  • Check if the path exists: ls $SEARCH_PATH"
    echo "  • Try without --recent filter"
    exit 0
fi

RESULT_COUNT=$(echo "$RESULTS" | wc -l)

if [ "$RESULT_COUNT" -ge "$MAX_RESULTS" ]; then
    echo -e "${YELLOW}Found $MAX_RESULTS+ results (showing first $MAX_RESULTS)${NC}"
else
    echo -e "${GREEN}Found $RESULT_COUNT result(s)${NC}"
fi
echo ""

# Display results with details
echo -e "${BLUE}━━━ SEARCH RESULTS ━━━${NC}"
echo ""

INDEX=1
echo "$RESULTS" | while read -r filepath; do
    if [ -z "$filepath" ]; then
        continue
    fi

    # Get file details
    FILENAME=$(basename "$filepath")
    DIRNAME=$(dirname "$filepath")
    SIZE=$(stat -c %s "$filepath" 2>/dev/null || echo "0")
    SIZE_HR=$(numfmt --to=iec-i --suffix=B "$SIZE" 2>/dev/null || echo "${SIZE}B")
    MODIFIED=$(stat -c %y "$filepath" 2>/dev/null | cut -d. -f1 || echo "Unknown")

    # Colorize by file type
    EXT="${FILENAME##*.}"
    case "$EXT" in
        py|sh|js)
            FILE_COLOR=$CYAN
            ;;
        yml|yaml|json)
            FILE_COLOR=$BLUE
            ;;
        png|jpg|jpeg)
            FILE_COLOR=$GREEN
            ;;
        *)
            FILE_COLOR=$NC
            ;;
    esac

    echo -e "${FILE_COLOR}[$INDEX] $FILENAME${NC}"
    echo "    Path: $DIRNAME"
    echo "    Size: $SIZE_HR"
    echo "    Modified: $MODIFIED"

    # Show permissions
    PERMS=$(stat -c %a "$filepath" 2>/dev/null || echo "unknown")
    if [ "$PERMS" = "755" ] || [ "$PERMS" = "777" ]; then
        echo -e "    Permissions: ${GREEN}$PERMS (executable)${NC}"
    else
        echo "    Permissions: $PERMS"
    fi

    # For script files, show first line (shebang)
    if [[ "$EXT" =~ ^(sh|py|js)$ ]]; then
        SHEBANG=$(head -1 "$filepath" 2>/dev/null || echo "")
        if [ -n "$SHEBANG" ]; then
            echo "    Type: $SHEBANG"
        fi
    fi

    # For image files, show dimensions if possible
    if [[ "$EXT" =~ ^(png|jpg|jpeg)$ ]]; then
        if command -v identify &>/dev/null; then
            DIMS=$(identify -format "%wx%h" "$filepath" 2>/dev/null || echo "unknown")
            echo "    Dimensions: $DIMS"
        fi
    fi

    echo ""
    ((INDEX++))
done

# Additional context
echo -e "${BLUE}━━━ QUICK ACTIONS ━━━${NC}"
echo ""
echo "Common operations:"
echo "  • View file: cat <path>"
echo "  • Edit file: nano <path> or vim <path>"
echo "  • Copy file: cp <source> <destination>"
echo "  • Show details: stat <path>"
echo "  • Find related: ./nexus-find.sh '<pattern>'"
echo ""

# Smart suggestions based on search
if [ -n "$QUERY" ]; then
    if [[ "$QUERY" == *"carousel"* ]]; then
        echo "Related searches:"
        echo "  • Find recent outputs: ./nexus-carousel-recent.sh"
        echo "  • Find templates: ./nexus-find.sh --type template"
    elif [[ "$QUERY" == *"docker"* ]]; then
        echo "Related commands:"
        echo "  • View containers: docker ps"
        echo "  • Check compose: cat /srv/docker/docker-compose.yml"
    elif [[ "$QUERY" == *"backup"* ]]; then
        echo "Related commands:"
        echo "  • Check backups: ./nexus-backup-status.sh"
        echo "  • View backup dir: ls -lh /mnt/backup/"
    fi
fi

# Show directory structure if only 1-2 results
if [ "$RESULT_COUNT" -le 2 ]; then
    echo ""
    echo "Directory context:"
    echo "$RESULTS" | while read -r filepath; do
        if [ -n "$filepath" ]; then
            PARENT=$(dirname "$filepath")
            echo ""
            echo "Contents of $PARENT:"
            ls -lh "$PARENT" 2>/dev/null | head -10
        fi
    done
fi

# Suggest narrowing search if too many results
if [ "$RESULT_COUNT" -ge "$MAX_RESULTS" ]; then
    echo ""
    echo -e "${YELLOW}Too many results. Consider:${NC}"
    echo "  • More specific query: ./nexus-find.sh 'exact_filename.ext'"
    echo "  • Add type filter: --type script"
    echo "  • Narrow path: --path /srv/outputs"
    echo "  • Recent only: --recent"
fi
