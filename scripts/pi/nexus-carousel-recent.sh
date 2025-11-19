#!/usr/bin/env bash
# nexus-carousel-recent.sh - View recent carousel outputs and metadata
# Usage: ./nexus-carousel-recent.sh [--days N] [--show-metadata]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default values
DAYS=7
SHOW_METADATA=false
OUTPUTS_DIR="/srv/outputs"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --days)
            DAYS="$2"
            shift 2
            ;;
        --show-metadata)
            SHOW_METADATA=true
            shift
            ;;
        *)
            echo "Usage: $0 [--days N] [--show-metadata]"
            exit 1
            ;;
    esac
done

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           RECENT CAROUSEL OUTPUTS                        ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Period: Last $DAYS days"
echo "Directory: $OUTPUTS_DIR"
echo ""

# Check if outputs directory exists
if [ ! -d "$OUTPUTS_DIR" ]; then
    echo -e "${RED}ERROR: Outputs directory not found: $OUTPUTS_DIR${NC}"
    exit 1
fi

# Find recent carousel outputs
echo -e "${BLUE}━━━ FINDING RECENT OUTPUTS ━━━${NC}"
CAROUSEL_FILES=$(find "$OUTPUTS_DIR" -name "*_final.png" -type f -mtime -"$DAYS" 2>/dev/null | sort -r)

if [ -z "$CAROUSEL_FILES" ]; then
    echo -e "${YELLOW}No carousel outputs found in the last $DAYS days${NC}"
    exit 0
fi

FILE_COUNT=$(echo "$CAROUSEL_FILES" | wc -l)
echo "Found: $FILE_COUNT carousel slides"
echo ""

# Group by carousel sets (assuming filename pattern: *_slide_N_final.png)
echo -e "${BLUE}━━━ CAROUSEL SETS ━━━${NC}"
echo ""

# Extract unique carousel identifiers (remove slide number)
CAROUSEL_SETS=$(echo "$CAROUSEL_FILES" | sed 's/_slide_[0-9]_final\.png$//' | sort -u)

SET_COUNT=0
while IFS= read -r carousel_base; do
    ((SET_COUNT++))

    # Get all slides for this carousel
    SLIDES=$(echo "$CAROUSEL_FILES" | grep "^${carousel_base}_slide_[0-9]_final.png$" || true)
    SLIDE_COUNT=$(echo "$SLIDES" | grep -c "." || echo "0")

    if [ "$SLIDE_COUNT" -eq 0 ]; then
        continue
    fi

    # Get the first slide to extract metadata
    FIRST_SLIDE=$(echo "$SLIDES" | head -1)
    TIMESTAMP=$(stat -c %y "$FIRST_SLIDE" | cut -d. -f1)
    TOTAL_SIZE=0

    echo -e "${CYAN}Carousel #$SET_COUNT${NC}"
    echo "  Base name: $(basename "$carousel_base")"
    echo "  Generated: $TIMESTAMP"
    echo "  Slides: $SLIDE_COUNT/5"

    # List individual slides
    echo "  Files:"
    echo "$SLIDES" | while read -r slide; do
        if [ -n "$slide" ]; then
            SLIDE_NUM=$(basename "$slide" | sed 's/.*_slide_\([0-9]\)_final\.png/\1/')
            SIZE=$(stat -c %s "$slide" 2>/dev/null || echo "0")
            SIZE_HR=$(numfmt --to=iec-i --suffix=B "$SIZE" 2>/dev/null || echo "${SIZE}B")
            TOTAL_SIZE=$((TOTAL_SIZE + SIZE))

            # Get image dimensions if possible
            if command -v identify &>/dev/null; then
                DIMENSIONS=$(identify -format "%wx%h" "$slide" 2>/dev/null || echo "unknown")
            else
                DIMENSIONS="unknown"
            fi

            echo "    Slide $SLIDE_NUM: $SIZE_HR ($DIMENSIONS)"
        fi
    done

    # Calculate total size
    TOTAL_SIZE=$(echo "$SLIDES" | xargs stat -c %s 2>/dev/null | awk '{sum+=$1} END {print sum}')
    TOTAL_SIZE_HR=$(numfmt --to=iec-i --suffix=B "$TOTAL_SIZE" 2>/dev/null || echo "${TOTAL_SIZE}B")
    echo "  Total size: $TOTAL_SIZE_HR"

    # Show metadata if requested
    if [ "$SHOW_METADATA" = true ]; then
        echo ""
        echo "  Metadata:"

        # Try to extract metadata from related JSON files
        JSON_FILE=$(find "$OUTPUTS_DIR" -name "*.json" -newer "$FIRST_SLIDE" -mmin -60 2>/dev/null | head -1)
        if [ -n "$JSON_FILE" ] && [ -f "$JSON_FILE" ]; then
            echo "    Related data: $(basename "$JSON_FILE")"
            if command -v jq &>/dev/null; then
                # Extract key fields if JSON is structured
                jq -r 'if .fact then "    Fact: " + .fact else empty end' "$JSON_FILE" 2>/dev/null || true
                jq -r 'if .category then "    Category: " + .category else empty end' "$JSON_FILE" 2>/dev/null || true
            fi
        else
            echo "    No metadata file found"
        fi

        # Check for image EXIF data
        if command -v exiftool &>/dev/null; then
            echo "    EXIF data:"
            exiftool -S -ImageDescription -Comment -Title "$FIRST_SLIDE" 2>/dev/null | sed 's/^/      /' || echo "      No EXIF data"
        fi
    fi

    echo ""
done <<< "$CAROUSEL_SETS"

echo -e "${BLUE}━━━ STATISTICS ━━━${NC}"
echo "Total carousel sets: $SET_COUNT"
echo "Total slides: $FILE_COUNT"

# Calculate total storage used
TOTAL_STORAGE=$(find "$OUTPUTS_DIR" -name "*_final.png" -type f -mtime -"$DAYS" -exec stat -c %s {} \; 2>/dev/null | \
    awk '{sum+=$1} END {print sum}')
TOTAL_STORAGE_HR=$(numfmt --to=iec-i --suffix=B "$TOTAL_STORAGE" 2>/dev/null || echo "${TOTAL_STORAGE}B")
echo "Total storage: $TOTAL_STORAGE_HR"

# Average per carousel
if [ "$SET_COUNT" -gt 0 ]; then
    AVG_SIZE=$((TOTAL_STORAGE / SET_COUNT))
    AVG_SIZE_HR=$(numfmt --to=iec-i --suffix=B "$AVG_SIZE" 2>/dev/null || echo "${AVG_SIZE}B")
    echo "Average per carousel: $AVG_SIZE_HR"
fi

# Daily breakdown
echo ""
echo "Daily generation count:"
find "$OUTPUTS_DIR" -name "*_final.png" -type f -mtime -"$DAYS" -printf '%TY-%Tm-%Td\n' 2>/dev/null | \
    sort | uniq -c | awk '{printf "  %s: %d slides\n", $2, $1}'
echo ""

# Check for incomplete carousels
echo -e "${BLUE}━━━ QUALITY CHECKS ━━━${NC}"
INCOMPLETE=0

while IFS= read -r carousel_base; do
    SLIDES=$(echo "$CAROUSEL_FILES" | grep "^${carousel_base}_slide_[0-9]_final.png$" || true)
    SLIDE_COUNT=$(echo "$SLIDES" | grep -c "." || echo "0")

    if [ "$SLIDE_COUNT" -gt 0 ] && [ "$SLIDE_COUNT" -lt 5 ]; then
        echo -e "${YELLOW}⚠ Incomplete carousel: $(basename "$carousel_base") (${SLIDE_COUNT}/5 slides)${NC}"
        ((INCOMPLETE++))
    fi
done <<< "$CAROUSEL_SETS"

if [ "$INCOMPLETE" -eq 0 ]; then
    echo -e "${GREEN}✓ All carousels complete (5 slides each)${NC}"
else
    echo -e "${YELLOW}⚠ $INCOMPLETE incomplete carousel(s) detected${NC}"
fi

# Check for failed generations (intermediate files without finals)
INTERMEDIATE_COUNT=$(find "$OUTPUTS_DIR" -name "slide_*.png" ! -name "*_final.png" -type f -mtime -"$DAYS" 2>/dev/null | wc -l)
if [ "$INTERMEDIATE_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠ $INTERMEDIATE_COUNT intermediate file(s) without finals (possible failures)${NC}"
fi
echo ""

# Recent activity timeline
echo -e "${BLUE}━━━ RECENT ACTIVITY ━━━${NC}"
echo "Last 10 generated slides:"
find "$OUTPUTS_DIR" -name "*_final.png" -type f -mtime -"$DAYS" -printf '%T@ %p\n' 2>/dev/null | \
    sort -rn | head -10 | while read timestamp path; do
        DATE=$(date -d @"${timestamp%.*}" '+%Y-%m-%d %H:%M:%S')
        FILENAME=$(basename "$path")
        echo "  $DATE - $FILENAME"
    done
echo ""

# Disk usage projection
echo -e "${BLUE}━━━ DISK USAGE PROJECTION ━━━${NC}"
if [ "$SET_COUNT" -gt 0 ] && [ "$DAYS" -gt 0 ]; then
    DAILY_AVG=$((SET_COUNT / DAYS))
    if [ "$DAILY_AVG" -eq 0 ]; then
        DAILY_AVG=1
    fi

    AVG_CAROUSEL_SIZE=$((TOTAL_STORAGE / SET_COUNT))
    MONTHLY_PROJECTED=$((DAILY_AVG * 30 * AVG_CAROUSEL_SIZE))
    MONTHLY_HR=$(numfmt --to=iec-i --suffix=B "$MONTHLY_PROJECTED" 2>/dev/null || echo "${MONTHLY_PROJECTED}B")

    echo "Average generation rate: ~$DAILY_AVG carousel(s) per day"
    echo "Projected monthly storage: ~$MONTHLY_HR"

    # Check available disk space
    AVAILABLE=$(df "$OUTPUTS_DIR" | awk 'NR==2 {print $4}')
    AVAILABLE_KB=$((AVAILABLE * 1024))

    if [ "$AVAILABLE_KB" -gt 0 ]; then
        MONTHS_REMAINING=$((AVAILABLE_KB / MONTHLY_PROJECTED))
        if [ "$MONTHS_REMAINING" -lt 3 ]; then
            echo -e "${YELLOW}⚠ Warning: Only ~$MONTHS_REMAINING months of storage remaining${NC}"
        else
            echo -e "${GREEN}✓ Storage sufficient for ~$MONTHS_REMAINING months${NC}"
        fi
    fi
fi
echo ""

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                   END OF REPORT                          ║"
echo "╚═══════════════════════════════════════════════════════════╝"
