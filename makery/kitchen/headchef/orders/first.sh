#!/bin/bash
# ============================================================================
#  HEAD CHEF: FIRST (The Recruiter)
# ============================================================================

# shellcheck source=../personality.sh
source "$(dirname "${BASH_SOURCE[0]}")/../personality.sh"

# --- validation ---
STATION_NAME="$1"
[ -z "$STATION_NAME" ] && H_SAY "Usage: bake first <station_name>"

KITCHEN_ROOT="$(dirname "${BASH_SOURCE[0]}")/../.."
STATION_DIR="$KITCHEN_ROOT/stations/$STATION_NAME"
STATIONS_REPO="${MAKERY_REGISTRY:-https://github.com/salomepoulain/makery-stations}"

H_STARTER "HIRING COOK & OPENING STATION: $STATION_NAME"

# --- Interactive Replacement Check ---
if [ -d "$STATION_DIR" ]; then
    echo -ne "  ${YELLOW}⚠${NC} The '$STATION_NAME' cook is already at their station. Replace them? (y/N): "
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        status "Firing the current cook and clearing the station..."
        rm -rf "$STATION_DIR"
    else
H_SAY "Keeping the current cook. No changes made."
        exit 0
    fi
fi

# --- Fetching ---
H_SAY "Fetching '$STATION_NAME' from the Registry..."
TMP_DIR=$(mktemp -d)
git clone --depth 1 --filter=blob:none --sparse "$STATIONS_REPO" "$TMP_DIR" > /dev/null 2>&1 || H_SAY "Failed to contact Registry."

cd "$TMP_DIR" || exit 1
git sparse-checkout set "stations/$STATION_NAME" > /dev/null 2>&1

if [ ! -d "stations/$STATION_NAME" ]; then
    cd - > /dev/null || exit
    rm -rf "$TMP_DIR"
H_SAY "The '$STATION_NAME' station doesn't exist in the Registry."
fi

cd - > /dev/null || exit
mkdir -p "$KITCHEN_ROOT/stations"
mv "$TMP_DIR/stations/$STATION_NAME" "$KITCHEN_ROOT/stations/"
rm -rf "$TMP_DIR"

H_SAY "The new cook has arrived."

# --- 1. Dependencies ---
if [ -f "$STATION_DIR/cook/contract/.prerequisite" ]; then
H_SAY "Checking personal tools..."
    while IFS= read -r dep || [ -n "$dep" ]; do
        [[ -z "$dep" || "$dep" == "#"* ]] && continue
        if ! command -v "$dep" &> /dev/null; then
H_SAY "✗ Missing: $dep"
            rm -rf "$STATION_DIR"
H_SAY "Missing essential tools. Station setup aborted."
        else
H_SAY "✓ Found: $dep"
        fi
    done < "$STATION_DIR/cook/contract/.prerequisite"
fi

# --- 2. Pantry (Static files) ---
if [ -d "$STATION_DIR/workbench/pantry" ]; then
H_SAY "Unpacking pantry ingredients..."
    for item in "$STATION_DIR/workbench/pantry"/*; do
        [ -f "$item" ] || continue
        filename=$(basename "$item")
        if [ ! -e "$filename" ]; then
            cp "$item" "$filename"
H_SAY "+ Stocked: $filename"
        else
H_SAY "~ Already stocked: $filename"
        fi
    done
fi

# --- 3. Contraband ---
if [ -f "$STATION_DIR/workbench/.contraband" ]; then
H_SAY "Hiding contraband..."
    touch .gitignore
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" == "#"* ]] && continue
        if ! grep -Fxq "$line" .gitignore; then
            echo "$line" >> .gitignore
H_SAY "+ Hidden: $line"
        fi
    done < "$STATION_DIR/workbench/.contraband"
fi

# --- 4. Setup Script ---
if [ -f "$STATION_DIR/cook/contract/hired.sh" ]; then
    if [ -f "$STATION_DIR/cook/personality.sh" ]; then
        # shellcheck source=/dev/null
        source "$STATION_DIR/cook/personality.sh"
    fi

    bash "$STATION_DIR/cook/contract/hired.sh"
fi

H_FINISHED
