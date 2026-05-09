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
        if [ -e "$path_to_clean" ]; then
            rm -rf "$path_to_clean"
            H_SAY "- Wiped: $path_to_clean"
        fi
    done < "$STATION_DIR/workbench/.dishsoap"
fi

H_SAY "Demolishing the physical station..."
rm -rf "$STATION_DIR"

H_SAY "The '$STATION_NAME' cook is permanently fired and their station is closed."

H_FINISHED
