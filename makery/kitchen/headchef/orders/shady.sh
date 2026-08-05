#!/bin/bash
# ============================================================================
#  HEAD CHEF: SHADY (Off-The-Books Storage)
# ============================================================================
# Moves this project's contraband (minus anything that's just disposable
# mess) into a .shadow/ folder outside the repo, and leaves a symlink
# behind at the original spot. __TRASH__ becomes __STASH__ on the first
# run. Safe to re-run any time — already-stashed paths are skipped, so
# hiring a new station later just picks up whatever's new.
#
# If .shadow/ already has data for this project (e.g. the repo was
# deleted and re-cloned) and there's nothing conflicting locally, it
# reconnects automatically. If both sides have real data, it asks.

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

H_STARTER "GOING SHADY"

REPO_ROOT=$(find_project_root) || {
    H_SAY "Error: .makery folder not found"
    exit 1
}
cd "$REPO_ROOT" || exit 1

PROJECT_NAME=$(basename "$REPO_ROOT")
SHADOW_DIR="${MAKERY_SHADOW_DIR:-$HOME/.shadow/projects}/$PROJECT_NAME"
STATIONS_DIR=".makery/kitchen/stations"

mkdir -p "$SHADOW_DIR"

# --- 1. Work out whether .shadow/ already has data for this project ---
SHADOW_HAS_CONTENT=false
[ "$(ls -A "$SHADOW_DIR" 2>/dev/null)" ] && SHADOW_HAS_CONTENT=true

TRASH_HAS_CONTENT=false
if [ -d "__TRASH__" ] && [ ! -L "__TRASH__" ] && [ "$(ls -A "__TRASH__" 2>/dev/null)" ]; then
    TRASH_HAS_CONTENT=true
fi

RECONNECT=false
CONFLICT_PROMPTED=false
if [ "$SHADOW_HAS_CONTENT" = true ] && [ ! -L "__STASH__" ]; then
    if [ "$TRASH_HAS_CONTENT" = true ]; then
        CONFLICT_PROMPTED=true
H_SAY "This project already has data in .shadow/, and __TRASH__ also has local content."
        echo -ne "  ${YELLOW}⚠${NC} Keep the existing .shadow/ data and leave __TRASH__ untouched? (Y/n): "
        read -r response
        if [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
H_SAY "Overwriting .shadow/ with __TRASH__'s contents..."
        else
            RECONNECT=true
H_SAY "Keeping .shadow/ — __TRASH__ is left as-is, nothing local was touched."
        fi
    else
        RECONNECT=true
H_SAY "Found existing .shadow/ data for this project — reconnecting."
    fi
fi

# --- 2. Turn __TRASH__ into __STASH__ (skipped when reconnecting) ---
if [ -d "__TRASH__" ] && [ ! -L "__TRASH__" ]; then
    if [ "$RECONNECT" = false ] && [ "$TRASH_HAS_CONTENT" = true ]; then
H_SAY "Turning __TRASH__ into __STASH__..."
        shopt -s dotglob nullglob
        for item in __TRASH__/*; do
            mv -f "$item" "$SHADOW_DIR/"
        done
        shopt -u dotglob nullglob
    fi
    rmdir "__TRASH__" 2>/dev/null
fi

if [ ! -e "__STASH__" ]; then
    ln -s "$SHADOW_DIR" "__STASH__"
H_SAY "+ __STASH__ now lives in .shadow/"
elif [ ! -L "__STASH__" ]; then
H_SAY "Error: __STASH__ already exists and isn't a symlink. Refusing to touch it."
    exit 1
fi

# --- 3. Stash (or reconnect) every hired station's contraband ---
stash_station() {
    local station_dir="$1"
    local station_name contraband dishsoap
    station_name=$(basename "$station_dir")
    contraband="$station_dir/workbench/.contraband"
    dishsoap="$station_dir/workbench/.dishsoap"

    [ -f "$contraband" ] || return 0

    while IFS= read -r pattern || [ -n "$pattern" ]; do
        [[ -z "$pattern" || "$pattern" == "#"* ]] && continue

        # Skip anything that's just disposable mess — no point stashing junk.
        if [ -f "$dishsoap" ] && grep -Fxq "$pattern" "$dishsoap"; then
            continue
        fi

        shopt -s nullglob globstar
        # shellcheck disable=SC2206 # intentional: splitting a glob pattern into matches
        local matches=( $pattern )
        shopt -u nullglob globstar

        for match in "${matches[@]}"; do
            [ -L "$match" ] && continue

            # Nothing local, but .shadow/ already has it — reconnect, don't move.
            if [ ! -e "$match" ] && [ -e "$SHADOW_DIR/$match" ]; then
                ln -s "$SHADOW_DIR/$match" "$match"
H_SAY "+ Reconnected ($station_name): $match"
                continue
            fi

            [ -e "$match" ] || continue

            # Both sides have real data for this one path.
            if [ -e "$SHADOW_DIR/$match" ]; then
                if [ "$CONFLICT_PROMPTED" = true ] && [ "$RECONNECT" = false ]; then
                    # User already chose "overwrite .shadow/ with local" up top — honor it here too.
                    rm -rf "${SHADOW_DIR:?}/$match"
                    mkdir -p "$SHADOW_DIR/$(dirname "$match")"
                    mv "$match" "$SHADOW_DIR/$match"
                    ln -s "$SHADOW_DIR/$match" "$match"
H_SAY "+ Stashed ($station_name): $match (overwrote .shadow/)"
                else
H_SAY "Both local and .shadow/ have $station_name's $match — skipping, resolve by hand."
                fi
                continue
            fi

            mkdir -p "$SHADOW_DIR/$(dirname "$match")"
            mv "$match" "$SHADOW_DIR/$match"
            ln -s "$SHADOW_DIR/$match" "$match"
H_SAY "+ Stashed ($station_name): $match"
        done
    done < "$contraband"

    # Let the station react to going shady (e.g. relocating memory into the stash).
    if [ -f "$station_dir/cook/contract/illegal.sh" ]; then
        if [ -f "$station_dir/cook/personality.sh" ]; then
            # shellcheck source=/dev/null
            source "$station_dir/cook/personality.sh"
        fi
        REPO_ROOT="$REPO_ROOT" SHADOW_DIR="$SHADOW_DIR" bash "$station_dir/cook/contract/illegal.sh"
    fi
}

if [ -d "$STATIONS_DIR" ]; then
    for station_dir in "$STATIONS_DIR"/*/; do
        [ "$(basename "$station_dir")" = "_empty_station" ] && continue
        [ -d "$station_dir" ] && stash_station "$station_dir"
    done
fi

H_SAY "Everything contraband now lives in .shadow/ — sync that folder however you like."

H_FINISHED
