#!/bin/bash
# ============================================================================
#  HEAD CHEF: GERMS / FRESH (Health Inspector is coming)
# ============================================================================

# shellcheck source=../personality.sh
source "$(dirname "${BASH_SOURCE[0]}")/../personality.sh"

H_STARTER "KILLING GERMS (Health Inspector Prep)"

KITCHEN_ROOT="$(dirname "${BASH_SOURCE[0]}")/../.."
STATIONS_DIR="$KITCHEN_ROOT/stations"

clean_station() {
    local station_dir=$1
    local station_name
    station_name=$(basename "$station_dir")
    local cleaned=false

    if [ -f "$station_dir/workbench/.dishsoap" ]; then
        while IFS= read -r path_to_clean || [ -n "$path_to_clean" ]; do
            # FIXED: Added quotes around the # to prevent Bash syntax SAYs
            if [[ -z "$path_to_clean" || "$path_to_clean" == "#"* ]]; then continue; fi

            if [ -e "$path_to_clean" ]; then
                rm -rf "$path_to_clean"
                if [ "$cleaned" = false ]; then
H_SAY "The cook is scrubbing the '$station_name' workbench:"
                     cleaned=true
                fi
H_SAY "- Scrubbed: $path_to_clean"
            fi
        done < "$station_dir/workbench/.dishsoap"
    fi
}

if [ -n "$1" ]; then
    # Clean just one station
    if [ -d "$STATIONS_DIR/$1" ]; then
        clean_station "$STATIONS_DIR/$1"
    else
H_SAY "The '$1' station doesn't exist."
    fi
else
    # Clean all stations
H_SAY "The Head Chef is screaming. Everyone is scrubbing their workbenches!"

    # Check if there are any stations at all before looping
    if [ -d "$STATIONS_DIR" ] && [ "$(ls -A "$STATIONS_DIR")" ]; then
        for dir in "$STATIONS_DIR"/*/; do
            [ -e "$dir" ] || continue
            [ "$(basename "$dir")" = "_empty_station" ] && continue
            clean_station "$dir"
        done
    fi
fi

H_SAY "The kitchen is spotless. We will pass the inspection."

H_FINISHED
