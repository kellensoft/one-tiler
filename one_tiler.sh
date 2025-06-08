#!/usr/bin/env bash

# Example:
# ./one-tiler.sh --icon-set feather --style linear --colors "#4065a8,#4682b4,#63a4d7" --dimensions "5120x1440" --padding-x 48 --padding-y 48

set -e

# Defaults
ICON_SET=""
STYLE="solid"
COLORS="#4065a8"
DIMENSIONS=""
PADDING_X=32
PADDING_Y=32

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --icon-set) ICON_SET="$2"; shift ;;
        --style) STYLE="$2"; shift ;;
        --colors) COLORS="$2"; shift ;;
        --dimensions) DIMENSIONS="$2"; shift ;;
        --padding-x) PADDING_X="$2"; shift ;;
        --padding-y) PADDING_Y="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Detect screen size if not provided
if [[ -z "$DIMENSIONS" ]]; then
    if command -v xrandr >/dev/null 2>&1; then
        DIMENSIONS=$(xrandr | grep '*' | awk '{print $1}' | head -n1)
    else
        echo "No --dimensions and xrandr not found. Please specify dimensions."; exit 1
    fi
fi
WIDTH=$(echo "$DIMENSIONS" | cut -dx -f1)
HEIGHT=$(echo "$DIMENSIONS" | cut -dx -f2)

# Validate icon set
if [[ -d "$ICON_SET" ]]; then
    ICON_DIR="$ICON_SET"
elif [[ -d "/usr/share/icons/${ICON_SET}/svg" ]]; then
    ICON_DIR="/usr/share/icons/${ICON_SET}/svg"
elif [[ -d "/usr/share/icons/${ICON_SET}" ]]; then
    ICON_DIR="/usr/share/icons/${ICON_SET}"
else
    echo "Error: Icon set '$ICON_SET' not found as a directory."
    exit 1
fi

# Prepare color list
IFS=',' read -ra COLOR_ARRAY <<< "$COLORS"

# Gradient logic
GRADIENT_DEF=""
FILL=""

if [[ "$STYLE" == "solid" ]]; then
    FILL="${COLOR_ARRAY[0]}"
else
    if [[ "$STYLE" == "linear" ]]; then
        ANGLE="90"
        GRADIENT_DEF="<linearGradient id='bg' gradientTransform='rotate($ANGLE)'>"
    elif [[ "$STYLE" == "radial" ]]; then
        GRADIENT_DEF="<radialGradient id='bg'>"
    else
        echo "Unsupported gradient style: $STYLE"; exit 1
    fi
    COUNT=0
    N_COLORS=${#COLOR_ARRAY[@]}
    for COLOR in "${COLOR_ARRAY[@]}"; do
        OFFSET=$(( 100 * COUNT / (N_COLORS-1) ))
        GRADIENT_DEF="${GRADIENT_DEF}<stop offset='${OFFSET}%' stop-color='${COLOR}'/>"
        COUNT=$((COUNT+1))
    done
    if [[ "$STYLE" == "linear" ]]; then
        GRADIENT_DEF="${GRADIENT_DEF}</linearGradient>"
    else
        GRADIENT_DEF="${GRADIENT_DEF}</radialGradient>"
    fi
    FILL="url(#bg)"
fi

# Icon placement
ICON_SIZE=48  # px
ICON_PATHS=($(find "$ICON_DIR" -type f -name "*.svg" | shuf))
COLS=$(( WIDTH / (ICON_SIZE + PADDING_X) ))
ROWS=$(( HEIGHT / (ICON_SIZE + PADDING_Y) ))

# SVG header
SVG="wallpaper.svg"
echo "<svg width='$WIDTH' height='$HEIGHT' xmlns='http://www.w3.org/2000/svg'>" > "$SVG"
if [[ "$STYLE" == "solid" ]]; then
    echo "<rect width='100%' height='100%' fill='$FILL'/>" >> "$SVG"
else
    echo "<defs>${GRADIENT_DEF}</defs>" >> "$SVG"
    echo "<rect width='100%' height='100%' fill='$FILL'/>" >> "$SVG"
fi

# Tiling icons
ICON_IDX=0
for ((row=0; row<ROWS; row++)); do
    for ((col=0; col<COLS; col++)); do
        X=$(( col * (ICON_SIZE + PADDING_X) + PADDING_X / 2 ))
        Y=$(( row * (ICON_SIZE + PADDING_Y) + PADDING_Y / 2 ))
        ICON="${ICON_PATHS[$ICON_IDX]}"
        if [[ -z "$ICON" ]]; then
            ICON_IDX=0
            ICON="${ICON_PATHS[$ICON_IDX]}"
        fi
        echo "<image href='file://$ICON' x='$X' y='$Y' width='$ICON_SIZE' height='$ICON_SIZE' opacity='0.85'/>" >> "$SVG"
        ICON_IDX=$((ICON_IDX+1))
    done
done

echo "</svg>" >> "$SVG"

echo "SVG wallpaper generated at: $SVG"
echo "To convert to PNG: rsvg-convert -o wallpaper.png wallpaper.svg"

# Optional: Uncomment the following line to automatically export as PNG if rsvg-convert is installed
# command -v rsvg-convert >/dev/null && rsvg-convert -o wallpaper.png wallpaper.svg && echo "PNG saved as wallpaper.png"
