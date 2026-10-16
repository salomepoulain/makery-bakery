#!/bin/bash
# ============================================================================
#  HEAD CHEF: FIRST (The Recruiter)
# ============================================================================

# shellcheck source=../personality.sh
source "$(dirname "${BASH_SOURCE[0]}")/../personality.sh"

# --- validation ---
STATION_NAME="$1"
if [ -z "$STATION_NAME" ]; then
    H_SAY "Usage: bake first <station_name>"
    exit 1
fi
case "$STATION_NAME" in
    */* | . | .. | _empty_station)
        H_SAY "'$STATION_NAME' isn't a station you can hire."
        exit 1
        ;;
esac

KITCHEN_ROOT="$(dirname "${BASH_SOURCE[0]}")/../.."
STATION_DIR="$KITCHEN_ROOT/stations/$STATION_NAME"
# shellcheck source=../registry.sh
source "$(dirname "${BASH_SOURCE[0]}")/../registry.sh"
STATIONS_REPO="$REGISTRY_URL"

H_STARTER "HIRING COOK & OPENING STATION: $STATION_NAME"

# --- Look in the registry first ---
H_SAY "Looking for '$STATION_NAME' in the Registry..."
TMP_DIR=$(mktemp -d)
IN_REGISTRY=0
if git clone --depth 1 --filter=blob:none --sparse "$STATIONS_REPO" "$TMP_DIR" > /dev/null 2>&1; then
    git -C "$TMP_DIR" sparse-checkout set "stations/$STATION_NAME" > /dev/null 2>&1
    [ -d "$TMP_DIR/stations/$STATION_NAME" ] && IN_REGISTRY=1
else
    H_SAY "Couldn't reach the Registry ($MAKERY_REGISTRY)."
fi

# FROM_REGISTRY=1: the station folder below is a fresh registry copy, safe to
# remove again. 0: it's the project's own local station, never removed here.
FROM_REGISTRY=0
if [ "$IN_REGISTRY" -eq 1 ] && [ -d "$STATION_DIR" ]; then
    echo -ne "  ${YELLOW}⚠${NC} The '$STATION_NAME' cook is already at their station. Replace them with the Registry's version? (y/N): "
    read -r response
    if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        rm -rf "$TMP_DIR"
        H_SAY "Keeping the current cook. No changes made."
        exit 0
    fi
    H_SAY "Firing the current cook and clearing the station..."
    rm -rf "$STATION_DIR"
fi

if [ "$IN_REGISTRY" -eq 1 ]; then
    mkdir -p "$KITCHEN_ROOT/stations"
    mv "$TMP_DIR/stations/$STATION_NAME" "$KITCHEN_ROOT/stations/"
    FROM_REGISTRY=1
    H_SAY "The new cook has arrived."
elif [ -d "$STATION_DIR" ]; then
    # Made here with `bake station`, not sent with `bake request` yet.
    H_SAY "'$STATION_NAME' isn't in the Registry, hiring your local station."
else
    rm -rf "$TMP_DIR"
    H_SAY "The '$STATION_NAME' station doesn't exist in the Registry or in this project."
    exit 1
fi
rm -rf "$TMP_DIR"

# --- 1. Dependencies ---
if [ -f "$STATION_DIR/workbench/.tools" ]; then
    H_SAY "Checking personal tools..."
    MISSING=0
    while IFS= read -r dep || [ -n "$dep" ]; do
        [[ -z "$dep" || "$dep" == "#"* ]] && continue
        if ! command -v "$dep" &> /dev/null; then
            H_SAY "✗ Missing: $dep"
            MISSING=1
        else
            H_SAY "✓ Found: $dep"
        fi
    done < "$STATION_DIR/workbench/.tools"
    if [ "$MISSING" -eq 1 ]; then
        [ "$FROM_REGISTRY" -eq 1 ] && rm -rf "$STATION_DIR"
        H_SAY "Missing essential tools. Station setup aborted."
        exit 1
    fi
fi

# --- 2. Pantry (Static files) ---
# Pantry unpacking is now handled explicitly in hired.sh, not auto-copied
# If a cook needs to unpack pantry items to the root, they should do so in their hired.sh
# if [ -d "$STATION_DIR/workbench/pantry" ]; then
# H_SAY "Unpacking pantry ingredients..."
#     for item in "$STATION_DIR/workbench/pantry"/*; do
#         [ -f "$item" ] || continue
#         filename=$(basename "$item")
#         if [ ! -e "$filename" ]; then
#             cp "$item" "$filename"
# H_SAY "+ Stocked: $filename"
#         else
# H_SAY "~ Already stocked: $filename"
#         fi
#     done
# fi

# --- 3. Countertop (.gitignore entries) ---
# .countertop is the sole source of truth for .gitignore - station authors
# write it by hand, including duplicating in anything from .contraband or
# .dishsoap that also needs gitignoring. No automatic union: writing it
# out explicitly is what makes a station author actually think about it.
if [ -f "$STATION_DIR/workbench/.countertop" ] && [ -f ".gitignore" ]; then
H_SAY "Hiding countertop..."
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" == "#"* ]] && continue
        if ! grep -Fxq "$line" .gitignore; then
            echo "$line" >> .gitignore
H_SAY "+ Hidden: $line"
        fi
    done < "$STATION_DIR/workbench/.countertop"
fi

# --- 4. Setup Script ---
# The countertop is untouchable: whatever this station's .countertop
# already claims locally (including a dangling symlink - the name is
# still claimed even if its target isn't there yet) gets snapshotted
# aside before hired.sh runs, and put back exactly as it was afterward -
# no matter what hired.sh does. hired.sh never needs to check for this
# itself.
if [ -f "$STATION_DIR/cook/contract/hired.sh" ]; then
    COUNTERTOP_BACKUP=$(mktemp -d)
    COUNTERTOP_PROTECTED=()

    # Put everything back, also when hiring gets interrupted (Ctrl-C):
    # otherwise .env, .claude and friends stay stuck in a temp folder.
    restore_countertop() {
        local path
        for path in "${COUNTERTOP_PROTECTED[@]}"; do
            [ -e "$COUNTERTOP_BACKUP/$path" ] || [ -L "$COUNTERTOP_BACKUP/$path" ] || continue
            rm -rf "$path"
            mkdir -p "$(dirname "$path")"
            mv "$COUNTERTOP_BACKUP/$path" "$path"
        done
        rm -rf "$COUNTERTOP_BACKUP"
    }
    trap restore_countertop EXIT
    trap 'restore_countertop; exit 130' INT TERM

    if [ -f "$STATION_DIR/workbench/.countertop" ]; then
        while IFS= read -r path || [ -n "$path" ]; do
            [[ -z "$path" || "$path" == "#"* ]] && continue

            # A name already claims the spot even if it's a dangling
            # symlink (e.g. .shadow/ hasn't synced in yet) - -e alone
            # would miss that, since it follows the link and fails on
            # a broken target. -L catches it either way.
            [ -e "$path" ] || [ -L "$path" ] || continue

            mkdir -p "$COUNTERTOP_BACKUP/$(dirname "$path")"
            mv "$path" "$COUNTERTOP_BACKUP/$path"
            COUNTERTOP_PROTECTED+=("$path")
        done < "$STATION_DIR/workbench/.countertop"
    fi

    if [ -f "$STATION_DIR/cook/personality.sh" ]; then
        # shellcheck source=/dev/null
        source "$STATION_DIR/cook/personality.sh"
    fi

    bash "$STATION_DIR/cook/contract/hired.sh"

    restore_countertop
    trap - EXIT INT TERM
fi

# --- 5. Auto-stash (if this project has already gone shady) ---
# Runs after hired.sh so the new station has real content to stash and
# illegal.sh (if any) has real content to react to, instead of a bare
# station directory with nothing built yet.
if [ -L "__stash__" ]; then
H_SAY "This project is already shady — stashing the new cook's contraband too..."
    MAKERY_QUIET_SHADY=1 bash "$KITCHEN_ROOT/headchef/orders/shady.sh"
fi

H_FINISHED
