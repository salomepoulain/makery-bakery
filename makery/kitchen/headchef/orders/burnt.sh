#!/bin/bash
# ============================================================================
#  HEAD CHEF: BURNT (Tear down a Station)
# ============================================================================

# shellcheck source=../personality.sh
source "$(dirname "${BASH_SOURCE[0]}")/../personality.sh"

if [ -z "$1" ]; then
    H_SAY "You didn't tell me which station to tear down."
fi

STATION_NAME="$1"
KITCHEN_ROOT="$(dirname "${BASH_SOURCE[0]}")/../.."
STATION_DIR="$KITCHEN_ROOT/stations/$STATION_NAME"

if [ ! -d "$STATION_DIR" ]; then
    H_SAY "The '$STATION_NAME' station doesn't even exist."
    exit 0
fi

H_STARTER "BAKING BURNT $STATION_NAME"

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

H_SAY "Demolishing the physical station..."
rm -rf "$STATION_DIR"

H_SAY "The '$STATION_NAME' cook is permanently fired and their station is closed."

H_FINISHED
