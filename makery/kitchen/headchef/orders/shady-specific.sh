#!/bin/bash
# ============================================================================
#  HEAD CHEF: SHADY-SPECIFIC (Pick something extra to stash)
# ============================================================================
# For anything .contraband doesn't know about — a manually gitignored
# folder, a one-off file. Pick from .gitignore entries not yet stashed,
# or pass a path directly: bake shady-specific data/
# Usage: ./shady-specific.sh [path]

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

H_STARTER "PICKING SOMETHING SHADY"

REPO_ROOT=$(find_project_root) || {
    H_SAY "Error: .makery folder not found"
    exit 1
}
cd "$REPO_ROOT" || exit 1

PROJECT_NAME=$(basename "$REPO_ROOT")
SHADOW_DIR="${MAKERY_SHADOW_DIR:-$HOME/.shadow/projects}/$PROJECT_NAME"

TARGET="$1"

# --- No path given: offer a picker of un-stashed .gitignore entries ---
if [ -z "$TARGET" ]; then
    OFFERED=()
    if [ -f .gitignore ]; then
        while IFS= read -r entry || [ -n "$entry" ]; do
            [[ -z "$entry" || "$entry" == "#"* ]] && continue
            entry="${entry%/}"
            [ -e "$entry" ] || continue
            [ -L "$entry" ] && continue
            OFFERED+=("$entry")
        done < .gitignore
    fi

    if [ ${#OFFERED[@]} -eq 0 ]; then
H_SAY "Nothing new in .gitignore to offer — everything's either already stashed or doesn't exist yet."
    else
H_SAY "Pick something to stash (0 to type a path yourself):"
        i=1
        for o in "${OFFERED[@]}"; do
            echo "  $i) $o"
            i=$((i + 1))
        done
        echo "  0) type a path myself"
        echo -ne "  > "
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#OFFERED[@]}" ]; then
            TARGET="${OFFERED[$((choice - 1))]}"
        fi
    fi

    if [ -z "$TARGET" ]; then
        echo -ne "  Path to stash: "
        read -r TARGET
    fi
fi

if [ -z "$TARGET" ]; then
H_SAY "No path given, nothing to do."
    exit 0
fi

TARGET="${TARGET%/}"

if [ -L "$TARGET" ]; then
H_SAY "'$TARGET' is already stashed."
    exit 0
fi

mkdir -p "$SHADOW_DIR"

# Nothing local, but .shadow/ already has it (e.g. after a delete + re-clone) — reconnect.
if [ ! -e "$TARGET" ] && [ -e "$SHADOW_DIR/$TARGET" ]; then
    mkdir -p "$(dirname "$TARGET")"
    ln -s "$SHADOW_DIR/$TARGET" "$TARGET"
H_SAY "+ Reconnected: $TARGET"
    H_FINISHED
    exit 0
fi

if [ ! -e "$TARGET" ]; then
H_SAY "Error: '$TARGET' doesn't exist locally or in .shadow/."
    exit 1
fi

if [ -e "$SHADOW_DIR/$TARGET" ]; then
H_SAY "Both local and .shadow/ already have '$TARGET' — skipping, resolve by hand."
    exit 0
fi

if [ -f .gitignore ] && ! grep -Fxq "$TARGET" .gitignore && ! grep -Fxq "$TARGET/" .gitignore; then
    echo "$TARGET" >> .gitignore
H_SAY "+ Added to .gitignore: $TARGET"
fi

mkdir -p "$SHADOW_DIR/$(dirname "$TARGET")"
mv "$TARGET" "$SHADOW_DIR/$TARGET"
ln -s "$SHADOW_DIR/$TARGET" "$TARGET"
H_SAY "+ Stashed: $TARGET"

H_FINISHED
