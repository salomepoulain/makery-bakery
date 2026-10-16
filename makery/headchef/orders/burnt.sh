#!/bin/bash
# ============================================================================
#  HEAD CHEF: BURNT (Tear down a Station)
# ============================================================================

# shellcheck source=../personality.sh
source "$(dirname "${BASH_SOURCE[0]}")/../personality.sh"

if [ -z "$1" ]; then
    H_SAY "You didn't tell me which station to tear down. Usage: bake burnt <name>"
    exit 1
fi

STATION_NAME="$1"
# An empty, dotted or nested name would point at stations/ or .makery itself.
case "$STATION_NAME" in
    */* | . | ..)
        H_SAY "'$STATION_NAME' isn't a station name."
        exit 1
        ;;
    _empty_station)
        H_SAY "That's the template for new stations, not a cook. Leaving it."
        exit 1
        ;;
esac
KITCHEN_ROOT="$(dirname "${BASH_SOURCE[0]}")/../.."
STATION_DIR="$KITCHEN_ROOT/stations/$STATION_NAME"

if [ ! -d "$STATION_DIR" ]; then
    H_SAY "The '$STATION_NAME' station doesn't even exist."
    exit 0
fi

H_STARTER "BAKING BURNT $STATION_NAME"

# Firing runs fired.sh and deletes files, so it only runs from a real terminal,
# never from an agent's command or a pipe like `echo y | bake burnt x`.
if [ ! -t 0 ] || [ ! -t 1 ]; then
    H_SAY "bake burnt deletes files, so it only runs from a real terminal. Nothing was changed."
    exit 1
fi
echo -ne "  ${HC_COLOR}$HC_ICON${NC} Fire '$STATION_NAME'? This runs its fired.sh and deletes its dishsoap, countertop files and the station. (y/N) "
read -r REPLY
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    H_SAY "The '$STATION_NAME' cook keeps their job. Nothing was changed."
    exit 0
fi

# 1. The Teardown Script (System Purge)
if [ -f "$STATION_DIR/cook/contract/fired.sh" ]; then
    # Load personality if it exists
    if [ -f "$STATION_DIR/cook/personality.sh" ]; then
        # shellcheck source=/dev/null
        source "$STATION_DIR/cook/personality.sh"
    fi

    bash "$STATION_DIR/cook/contract/fired.sh"
fi

# 2. Local Cleanup
if [ -f "$STATION_DIR/workbench/.dishsoap" ]; then
     H_SAY "Scrubbing the workbench before tearing it down..."
     while IFS= read -r path_to_clean || [ -n "$path_to_clean" ]; do
        if [[ -z "$path_to_clean" || "$path_to_clean" == \#* ]]; then continue; fi

        # Expand glob patterns (e.g. *.aux, report/**/*.aux) as well as literal paths
        shopt -s nullglob globstar
        # shellcheck disable=SC2206 # intentional: splitting a glob pattern into matches
        matches=( $path_to_clean )
        shopt -u nullglob globstar

        for match in "${matches[@]}"; do
            if [ -e "$match" ]; then
                rm -rf "$match"
                H_SAY "- Wiped: $match"
            fi
        done
    done < "$STATION_DIR/workbench/.dishsoap"
fi

# 3. Countertop Cleanup
# Unlike hiring (which protects the countertop), firing gets rid of it -
# the station's gone, so is everything it claimed. Note: for anything
# that's a symlink into .shadow/ (e.g. .claude), this only removes the
# local symlink - the real content stays safe in .shadow/ either way.
if [ -f "$STATION_DIR/workbench/.countertop" ]; then
     H_SAY "Clearing the countertop..."
     while IFS= read -r path_to_clean || [ -n "$path_to_clean" ]; do
        if [[ -z "$path_to_clean" || "$path_to_clean" == \#* ]]; then continue; fi

        # Expand glob patterns (e.g. *.bak.*) as well as literal paths
        shopt -s nullglob globstar
        # shellcheck disable=SC2206 # intentional: splitting a glob pattern into matches
        matches=( $path_to_clean )
        shopt -u nullglob globstar

        for match in "${matches[@]}"; do
            if [ -e "$match" ] || [ -L "$match" ]; then
                rm -rf "$match"
H_SAY "- Cleared: $match"
            fi
        done
    done < "$STATION_DIR/workbench/.countertop"
fi

H_SAY "Demolishing the physical station..."
rm -rf "$STATION_DIR"

H_SAY "The '$STATION_NAME' cook is permanently fired and their station is closed."

H_FINISHED
