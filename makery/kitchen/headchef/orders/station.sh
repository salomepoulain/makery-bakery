#!/bin/bash
# ============================================================================
#  HEAD CHEF: STATION SCAFFOLDER
# ============================================================================
# Scaffolds a new station from the official template
# Usage: ./station.sh <name>

set -e

# shellcheck source=../personality.sh
source "$(dirname "${BASH_SOURCE[0]}")/../personality.sh"

H_STARTER "SCAFFOLDING NEW STATION"

# Validate name argument
if [[ -z "$1" ]]; then
    H_SAY "Error: station name required"
    H_SAY "Usage: bake station <name>"
    exit 1
fi

STATION_NAME="$1"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    H_SAY "Error: not in a git repository"
    exit 1
}

STATION_DIR="$REPO_ROOT/.makery/kitchen/stations/$STATION_NAME"

# Check station doesn't already exist
if [[ -d "$STATION_DIR" ]]; then
    H_SAY "Error: station '$STATION_NAME' already exists at $STATION_DIR"
    exit 1
fi

H_SAY "Fetching template from salomepoulain/makery-bakery..."

# Use GitHub API to get the file tree structure
TREE_DATA=$(gh api repos/salomepoulain/makery-bakery/git/trees/HEAD?recursive=1 --jq '.tree[] | select(.path | startswith("makery/kitchen/stations/_empty_station/"))' 2>/dev/null) || {
    H_SAY "Error: failed to fetch template tree from GitHub"
    H_SAY "Make sure you're authenticated: gh auth login"
    exit 1
}

# Create station directory
mkdir -p "$STATION_DIR"

# Download each file from the template
while IFS= read -r line; do
    if [[ -z "$line" ]]; then
        continue
    fi

    # Parse the JSON line
    FILE_PATH=$(echo "$line" | jq -r '.path')
    FILE_TYPE=$(echo "$line" | jq -r '.type')

    # Strip "makery/kitchen/stations/_empty_station/" prefix
    RELATIVE_PATH="${FILE_PATH#makery/kitchen/stations/_empty_station/}"

    if [[ "$FILE_TYPE" == "blob" ]]; then
        TARGET_PATH="$STATION_DIR/$RELATIVE_PATH"
        TARGET_DIR=$(dirname "$TARGET_PATH")

        # Create parent directories
        mkdir -p "$TARGET_DIR"

        # Download file content from GitHub
        gh api repos/salomepoulain/makery-bakery/contents/"$FILE_PATH" --jq '.content' | base64 -d > "$TARGET_PATH" 2>/dev/null || {
            H_SAY "Error: failed to download $FILE_PATH"
            exit 1
        }
    elif [[ "$FILE_TYPE" == "tree" ]]; then
        # Create directory
        mkdir -p "$STATION_DIR/$RELATIVE_PATH"
    fi
done <<< "$TREE_DATA"

# Make scripts executable
find "$STATION_DIR" -name "*.sh" -type f -exec chmod +x {} \;

H_SAY "✓ Station '$STATION_NAME' created at .makery/kitchen/stations/$STATION_NAME"
H_SAY ""
H_SAY "Next steps:"
H_SAY "  1. Edit cook/personality.sh to customize COOK_NAME, COOK_ICON, COOK_COLOR"
H_SAY "  2. Edit cook/contract/.prerequisite if your station needs system dependencies"
H_SAY "  3. Edit cook/contract/hired.sh to add setup steps (e.g., create venv)"
H_SAY "  4. Edit cook/recipes/ to add your station's recipes"
H_SAY "  5. Run 'bake first $STATION_NAME' to hire the station"

H_FINISHED
