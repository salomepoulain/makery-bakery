#!/bin/bash
# ============================================================================
#  HEAD CHEF: SHADY (Off-The-Books Storage)
# ============================================================================
# bake shady               - moves every hired station's contraband into
#                             .shadow/ outside the repo, then makes the
#                             project match the stash (see below).
#                             __stash__ is a symlink to that .shadow/ folder.
# bake shady "<path>"      - stashes just that one path instead, for
#                             anything .contraband doesn't know about (a
#                             manually gitignored folder, a one-off file).
#                             The path you type is what becomes the symlink:
#                             `bake shady data` links the whole folder,
#                             `bake shady data/big.db` links only the file.
#
# The stash mirrors the project's layout and is the only record of what's
# stashed. For each entry in it, the project gets a symlink at the highest
# level that doesn't exist locally yet: if data/ exists locally, only
# data/big.db is linked; if it doesn't, data/ itself is. That reproduces
# what was typed, because the parent folder existed when it was stashed.
#
# shady never picks a winner: if a path exists both locally and in the
# stash, it warns and leaves both alone. Delete the copy you don't want
# and run it again. Symlinks into the stash whose target is gone get
# removed, since they hold no data.
#
# Safe to re-run any time.

# shellcheck source=../personality.sh
source "$(dirname "${BASH_SOURCE[0]}")/../personality.sh"

# Called from inside another order (e.g. first.sh): that order already drew
# the banner, so don't draw a second one around ours.
if [ "${MAKERY_QUIET_SHADY:-0}" = "1" ]; then
    H_STARTER() { :; }
    H_FINISHED() { :; }
fi

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

mkdir -p "$SHADOW_DIR" 2>/dev/null

# .shadow/ may live on a drive that isn't plugged in. Every stash link would
# then look dead and get pruned, so stop before touching anything.
if [ ! -d "$SHADOW_DIR" ]; then
    H_SAY "Error: the stash isn't reachable ($SHADOW_DIR). Is the drive with .shadow/ plugged in? Nothing was changed."
    exit 1
fi

# The stash layout replaced the old ledger file.
rm -f "$SHADOW_DIR/.ledger"

# --- Make sure __stash__ points at .shadow/ ---
if [ ! -e "__stash__" ]; then
    ln -s "$SHADOW_DIR" "__stash__"
    H_SAY "+ __stash__ now lives in .shadow/"
elif [ ! -L "__stash__" ]; then
    H_SAY "Error: __stash__ already exists and isn't a symlink. Refusing to touch it."
    exit 1
fi

# A tracked symlink into .shadow/ is broken on every other machine, so
# anything shady links gets gitignored.
ignore_add() {
    local path="$1"
    [ -f .gitignore ] || return 0
    grep -Fxq -e "$path" -e "$path/" -e "/$path" -e "/$path/" .gitignore && return 0
    echo "$path" >> .gitignore
    H_SAY "+ Added to .gitignore: $path"
}

two_sources() {
    H_SAY "Two sources of truth for $1 (local and __stash__). Delete the one you don't want and run bake shady again."
}

# Move one local path into the stash and leave a symlink behind.
stash_path() {
    local path="$1" label="$2"
    [ -L "$path" ] && return 0
    [ -e "$path" ] || return 0
    if [ -e "$SHADOW_DIR/$path" ]; then
        two_sources "$path"
        return 0
    fi
    mkdir -p "$SHADOW_DIR/$(dirname "$path")"
    mv "$path" "$SHADOW_DIR/$path"
    ln -s "$SHADOW_DIR/$path" "$path"
    ignore_add "$path"
    H_SAY "+ Stashed${label}: $path"
}

# Make the project match one stash entry (see the rule in the header).
link_from_stash() {
    local path="$1"
    local src="$SHADOW_DIR/$path"

    if [ -L "$path" ]; then
        [ "$(readlink "$path")" = "$src" ] || two_sources "$path"
    elif [ ! -e "$path" ]; then
        mkdir -p "$(dirname "$path")"
        ln -s "$src" "$path"
        ignore_add "$path"
        H_SAY "+ Linked: $path"
    elif [ -d "$path" ] && [ -d "$src" ] && [ ! -L "$src" ]; then
        local child
        for child in "$src"/* "$src"/.*; do
            [ -e "$child" ] || [ -L "$child" ] || continue
            case "$(basename "$child")" in .|..|.DS_Store) continue ;; esac
            link_from_stash "$path/$(basename "$child")"
        done
    else
        two_sources "$path"
    fi
}

sync_from_stash() {
    local entry
    for entry in "$SHADOW_DIR"/* "$SHADOW_DIR"/.*; do
        [ -e "$entry" ] || [ -L "$entry" ] || continue
        case "$(basename "$entry")" in
            .|..|.DS_Store|.git|.makery|__stash__) continue ;;
        esac
        link_from_stash "$(basename "$entry")"
    done
}

prune_dead_links() {
    local link
    while IFS= read -r link; do
        link="${link#./}"
        case "$(readlink "$link")" in
            "$SHADOW_DIR"/*) [ -e "$link" ] || { rm "$link"; H_SAY "- Removed dead link: $link"; } ;;
        esac
    done < <(find . -path ./.git -prune -o -type l -print)
}

TARGET="$1"

if [ -n "$TARGET" ]; then
    # ========================================================================
    #  SPECIFIC MODE: bake shady "<path>"
    # ========================================================================
    TARGET="${TARGET%/}"

    if [ -L "$TARGET" ]; then
        H_SAY "'$TARGET' is already stashed."
    elif [ -e "$TARGET" ]; then
        stash_path "$TARGET" ""
    elif [ -e "$SHADOW_DIR/$TARGET" ]; then
        link_from_stash "$TARGET"
    else
        H_SAY "Error: '$TARGET' doesn't exist locally or in __stash__."
        exit 1
    fi

    H_FINISHED
    exit 0
fi

# ============================================================================
#  REGULAR MODE: bake shady (no path given)
# ============================================================================

# --- Stash every hired station's contraband ---
stash_contraband() {
    local station_dir="$1"
    local station_name contraband dishsoap pattern match
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
            stash_path "$match" " ($station_name)"
        done
    done < "$contraband"
}

# Let a station react to going shady (e.g. relocating memory into the stash).
run_illegal() {
    local station_dir="$1"
    [ -f "$station_dir/cook/contract/illegal.sh" ] || return 0
    if [ -f "$station_dir/cook/personality.sh" ]; then
        # shellcheck source=/dev/null
        source "$station_dir/cook/personality.sh"
    fi
    REPO_ROOT="$REPO_ROOT" SHADOW_DIR="$SHADOW_DIR" bash "$station_dir/cook/contract/illegal.sh"
}

STATIONS=()
if [ -d "$STATIONS_DIR" ]; then
    for station_dir in "$STATIONS_DIR"/*/; do
        [ "$(basename "$station_dir")" = "_empty_station" ] && continue
        [ -d "$station_dir" ] && STATIONS+=("$station_dir")
    done
fi

for station_dir in "${STATIONS[@]}"; do
    stash_contraband "$station_dir"
done

sync_from_stash
prune_dead_links

for station_dir in "${STATIONS[@]}"; do
    run_illegal "$station_dir"
done

H_SAY "Everything contraband now lives in .shadow/ — sync that folder however you like."

H_FINISHED
