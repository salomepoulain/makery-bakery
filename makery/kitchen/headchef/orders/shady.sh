#!/bin/bash
# ============================================================================
#  HEAD CHEF: SHADY (Off-The-Books Storage)
# ============================================================================
# Moves this project's contraband (minus anything that's just disposable
# mess) into a .shadow/ folder outside the repo, and leaves a symlink
# behind at the original spot: __stash__. Safe to re-run any time —
# already-stashed paths are skipped, so hiring a new station later just
# picks up whatever's new.
#
# If .shadow/ already has data for this project (e.g. the repo was
# deleted and re-cloned), __stash__ just symlinks straight to whatever's
# already there — no migration, no prompting, no renaming dance. A
# genuinely local, unmanaged scratch/discard folder is a separate concern
# (see __trash__ in pockets/.contraband) — this script doesn't touch it.

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

# --- 1. Make sure __stash__ points at .shadow/ ---
if [ ! -e "__stash__" ]; then
    ln -s "$SHADOW_DIR" "__stash__"
H_SAY "+ __stash__ now lives in .shadow/"
elif [ ! -L "__stash__" ]; then
H_SAY "Error: __stash__ already exists and isn't a symlink. Refusing to touch it."
    exit 1
fi

# --- 2. Stash (or reconnect) every hired station's contraband ---
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

            # Both sides have real data for this one path — no auto-merge,
            # resolve by hand.
            if [ -e "$SHADOW_DIR/$match" ]; then
H_SAY "Both local and .shadow/ have $station_name's $match — skipping, resolve by hand."
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
