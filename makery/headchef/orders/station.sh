#!/bin/bash
# ============================================================================
#  HEAD CHEF: STATION SCAFFOLDER
# ============================================================================
# Scaffolds a new station from the kitchen's own _empty_station template
# Usage: ./station.sh <name>

set -e

# shellcheck source=../personality.sh
source "$(dirname "${BASH_SOURCE[0]}")/../personality.sh"

find_project_root() {
    local current="$PWD"
    while [[ "$current" != "/" ]]; do
        if [[ -d "$current/.makery" ]]; then
            echo "$current"
            return 0
        fi
        current=$(dirname "$current")
    done
    return 1
}

H_STARTER "SCAFFOLDING NEW STATION"

# Validate name argument
if [[ -z "$1" ]]; then
    H_SAY "Error: station name required"
    H_SAY "Usage: bake station <name>"
    exit 1
fi

STATION_NAME="$1"
case "$STATION_NAME" in
    */* | . | .. | _empty_station)
        H_SAY "Error: '$STATION_NAME' isn't a usable station name"
        exit 1
        ;;
esac
REPO_ROOT=$(find_project_root) || {
    H_SAY "Error: .makery folder not found"
    exit 1
}

STATION_DIR="$REPO_ROOT/.makery/stations/$STATION_NAME"

# Check station doesn't already exist
if [[ -d "$STATION_DIR" ]]; then
    H_SAY "Error: station '$STATION_NAME' already exists at $STATION_DIR"
    exit 1
fi

# The template ships with every kitchen, so this works offline and without gh.
TEMPLATE_DIR="$REPO_ROOT/.makery/stations/_empty_station"
if [[ ! -d "$TEMPLATE_DIR" ]]; then
    H_SAY "Error: template not found at $TEMPLATE_DIR"
    exit 1
fi
cp -R "$TEMPLATE_DIR" "$STATION_DIR"

# Make scripts executable
find "$STATION_DIR" -name "*.sh" -type f -exec chmod +x {} \;

H_SAY "✓ Station '$STATION_NAME' created at .makery/stations/$STATION_NAME"
H_SAY ""
H_SAY "Next steps:"
H_SAY "  1. Edit cook/personality.sh to customize COOK_NAME, COOK_ICON, COOK_COLOR"
H_SAY "  2. Edit workbench/.tools if your station needs system dependencies"
H_SAY "  3. Edit cook/contract/hired.sh to add setup steps (e.g., create venv)"
H_SAY "  4. Edit cook/skills/ to add your station's skills"
H_SAY "  5. Hire it here with 'bake first $STATION_NAME' (runs hired.sh)"
H_SAY "  6. Try a command with 'bake $STATION_NAME <command>'"
H_SAY "  7. Send it to your registry with 'bake request'"

H_FINISHED
