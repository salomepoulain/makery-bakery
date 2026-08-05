#!/bin/bash
# ============================================================================
#  HEAD CHEF: SHADY (Off-The-Books Storage)
# ============================================================================
# Moves this project's contraband (minus anything that's just disposable
# mess) into a .shadow/ folder outside the repo, and leaves a symlink
# behind at the original spot. __TRASH__ becomes __STASH__ on the first
# run. Safe to re-run any time — already-stashed paths are skipped, so
# hiring a new station later just picks up whatever's new.

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

# --- 1. Turn __TRASH__ into __STASH__ (first run only) ---
if [ -d "__TRASH__" ] && [ ! -L "__TRASH__" ]; then
H_SAY "Turning __TRASH__ into __STASH__..."
    shopt -s dotglob nullglob
    for item in __TRASH__/*; do
        mv "$item" "$SHADOW_DIR/"
    done
    shopt -u dotglob nullglob
    rmdir "__TRASH__" 2>/dev/null
fi

if [ ! -e "__STASH__" ]; then
    ln -s "$SHADOW_DIR" "__STASH__"
H_SAY "+ __STASH__ now lives in .shadow/"
elif [ ! -L "__STASH__" ]; then
H_SAY "Error: __STASH__ already exists and isn't a symlink. Refusing to touch it."
    exit 1
fi

# --- 2. Stash every hired station's contraband (minus dishsoap) ---
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
            [ -e "$match" ] || continue

            mkdir -p "$SHADOW_DIR/$(dirname "$match")"
            mv "$match" "$SHADOW_DIR/$match"
            ln -s "$SHADOW_DIR/$match" "$match"
H_SAY "+ Stashed ($station_name): $match"
        done
    done < "$contraband"
}

if [ -d "$STATIONS_DIR" ]; then
    for station_dir in "$STATIONS_DIR"/*/; do
        [ "$(basename "$station_dir")" = "_empty_station" ] && continue
        [ -d "$station_dir" ] && stash_station "$station_dir"
    done
fi

H_SAY "Everything contraband now lives in .shadow/ — sync that folder however you like."

H_FINISHED
