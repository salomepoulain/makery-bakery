#!/bin/bash
# ============================================================================
#  HEAD CHEF: SHADY (Off-The-Books Storage)
# ============================================================================
# bake shady               - moves every hired station's contraband (minus
#                             disposable mess) into .shadow/ outside the
#                             repo, leaving a symlink behind: __stash__.
# bake shady "<path>"      - stashes just that one path instead, for
#                             anything .contraband doesn't know about (a
#                             manually gitignored folder, a one-off file).
#
# Both are safe to re-run any time — already-stashed paths are skipped, so
# hiring a new station later just picks up whatever's new.
#
# .shadow/projects/<name>/.ledger keeps a flat list of every relative path
# that's supposed to be a symlink for this project. Whenever .shadow/
# already has data for this project (e.g. the repo was deleted and
# re-cloned, or .shadow/ just synced in fresh from another machine),
# every ledgered path gets reconnected straight from the ledger — no
# migration, no prompting, no relying on .contraband still matching
# anything locally. A genuinely local, unmanaged scratch/discard folder
# is a separate concern (see __trash__ in pockets/.contraband) — this
# script doesn't touch it.

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
STATIONS_DIR=".makery/stations"
LEDGER="$SHADOW_DIR/.ledger"

mkdir -p "$SHADOW_DIR"
touch "$LEDGER"

# Self-heal: every top-level entry actually sitting in .shadow/ is
# "supposed to be a symlink" for this project, however it got there
# (stashed here before the ledger existed, synced in from another
# machine, placed by hand). Keep the ledger in sync with reality so it
# never silently misses pre-existing content.
shopt -s dotglob nullglob
for entry in "$SHADOW_DIR"/*; do
    name="$(basename "$entry")"
    [ "$name" = ".ledger" ] && continue
    grep -Fxq "$name" "$LEDGER" || echo "$name" >> "$LEDGER"
done
shopt -u dotglob nullglob

# --- Make sure __stash__ points at .shadow/ ---
if [ ! -e "__stash__" ]; then
    ln -s "$SHADOW_DIR" "__stash__"
H_SAY "+ __stash__ now lives in .shadow/"
elif [ ! -L "__stash__" ]; then
H_SAY "Error: __stash__ already exists and isn't a symlink. Refusing to touch it."
    exit 1
fi

# Record a path as "supposed to be a symlink" (dedup) - safe to call
# whether it's newly stashed, newly reconnected, or still conflicted.
ledger_add() {
    local path="$1"
    grep -Fxq "$path" "$LEDGER" || echo "$path" >> "$LEDGER"
}

TARGET="$1"

if [ -n "$TARGET" ]; then
    # ========================================================================
    #  SPECIFIC MODE: bake shady "<path>"
    # ========================================================================
    TARGET="${TARGET%/}"

    if [ -L "$TARGET" ]; then
H_SAY "'$TARGET' is already stashed."
        exit 0
    fi

    # Nothing local, but .shadow/ already has it — reconnect, don't move.
    if [ ! -e "$TARGET" ] && [ -e "$SHADOW_DIR/$TARGET" ]; then
        mkdir -p "$(dirname "$TARGET")"
        ln -s "$SHADOW_DIR/$TARGET" "$TARGET"
        ledger_add "$TARGET"
H_SAY "+ Reconnected: $TARGET"
        H_FINISHED
        exit 0
    fi

    if [ ! -e "$TARGET" ]; then
H_SAY "Error: '$TARGET' doesn't exist locally or in .shadow/."
        exit 1
    fi

    # Both sides have real data for this one path — no auto-merge, resolve
    # by hand.
    if [ -e "$SHADOW_DIR/$TARGET" ]; then
        ledger_add "$TARGET"
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
    ledger_add "$TARGET"
H_SAY "+ Stashed: $TARGET"

    H_FINISHED
    exit 0
fi

# ============================================================================
#  REGULAR MODE: bake shady (no path given)
# ============================================================================

# --- Reconnect everything the ledger already knows about ---
# This is what makes .shadow/ syncing in from another machine "just work":
# no glob-matching, no dependency on any station's .contraband still
# describing the same pattern - the ledger is the source of truth.
while IFS= read -r path || [ -n "$path" ]; do
    [ -z "$path" ] && continue
    [ -L "$path" ] && continue

    if [ ! -e "$path" ] && [ -e "$SHADOW_DIR/$path" ]; then
        mkdir -p "$(dirname "$path")"
        ln -s "$SHADOW_DIR/$path" "$path"
H_SAY "+ Reconnected (ledger): $path"
    elif [ -e "$path" ] && [ -e "$SHADOW_DIR/$path" ]; then
H_SAY "Both local and .shadow/ have $path — skipping, resolve by hand."
    fi
done < "$LEDGER"

# --- Stash (or reconnect) every hired station's contraband ---
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

            # Nothing local, but .shadow/ already has it — reconnect, don't
            # move. (The ledger pass above already handles this for
            # anything previously stashed; this is the fallback for
            # .shadow/ content that predates the ledger.)
            if [ ! -e "$match" ] && [ -e "$SHADOW_DIR/$match" ]; then
                ln -s "$SHADOW_DIR/$match" "$match"
                ledger_add "$match"
H_SAY "+ Reconnected ($station_name): $match"
                continue
            fi

            [ -e "$match" ] || continue

            # Both sides have real data for this one path — no auto-merge,
            # resolve by hand.
            if [ -e "$SHADOW_DIR/$match" ]; then
                ledger_add "$match"
H_SAY "Both local and .shadow/ have $station_name's $match — skipping, resolve by hand."
                continue
            fi

            mkdir -p "$SHADOW_DIR/$(dirname "$match")"
            mv "$match" "$SHADOW_DIR/$match"
            ln -s "$SHADOW_DIR/$match" "$match"
            ledger_add "$match"
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
