#!/bin/bash
# ============================================================================
#  HEAD CHEF: SAFE (Stock the offline registry)
# ============================================================================
# Copies a station from the online registry into the offline registry
# (~/.makery-bakery/stations/), but only if none of its scripts reach the
# network or install software. A station that does is refused, unless you
# pass --force. Without a name, every station already in the offline
# registry is checked and copied again.
#
# The bake binary writes an offline copy of itself next to the registry
# afterwards, so `rsync ~/.makery-bakery` carries everything to a machine
# without internet.

# shellcheck source=../personality.sh
source "$(dirname "${BASH_SOURCE[0]}")/../personality.sh"
# shellcheck source=../registry.sh
source "$(dirname "${BASH_SOURCE[0]}")/../registry.sh"

if [ "${MAKERY_OFFLINE:-}" = 1 ]; then
    H_SAY "This is an offline bake. 'bake safe' needs the online registry, so run it on a machine with internet."
    exit 1
fi

STATION_NAME="${1:-}"
FORCE="${2:-}"

case "$STATION_NAME" in
    */* | . | .. | _empty_station)
        H_SAY "'$STATION_NAME' isn't a station you can make safe."
        exit 1
        ;;
esac

# Words that mean "reaches the network or installs something". Matched as
# whole words, in every script of the station. Comments don't count: lines
# that start with # or //, and anything after " #" at the end of a line.
DANGER='(^|[^[:alnum:]_.-])(curl|wget|git[[:space:]]+(clone|pull|push|fetch|remote|submodule)|gh|pip3?[[:space:]]+install|uv[[:space:]]+(pip|add|sync|tool|run)|uvx|conda[[:space:]]+(install|create)|mamba|micromamba|brew|apt(-get)?|yum|dnf|npm|npx|pnpm|yarn|cargo[[:space:]]+install|go[[:space:]]+(install|get)|docker|podman|apptainer|singularity|sudo|ssh|scp|sftp|rsync|nc|telnet|ftp)([^[:alnum:]_-]|$)|--install-extension|https?://'

H_STARTER "MAKING STATIONS SAFE FOR OFFLINE USE"

if [ -z "$STATION_NAME" ]; then
    NAMES=()
    for dir in "$OFFLINE_REGISTRY"/stations/*/; do
        [ -d "$dir" ] && NAMES+=("$(basename "$dir")")
    done
    if [ ${#NAMES[@]} -eq 0 ]; then
        H_SAY "The offline registry is still empty. Add a station with: bake safe <name>"
        H_LINE
        exit 0
    fi
    H_SAY "Checking every station in the offline registry again: ${NAMES[*]}"
else
    NAMES=("$STATION_NAME")
fi

# --- Fetch the online registry once ---
H_SAY "Fetching from the online registry ($MAKERY_REGISTRY)..."
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
if [ -d "$REGISTRY_URL/stations" ]; then
    cp -R "$REGISTRY_URL/stations" "$TMP_DIR/stations"
elif git clone --depth 1 --filter=blob:none --sparse "$REGISTRY_URL" "$TMP_DIR" > /dev/null 2>&1; then
    git -C "$TMP_DIR" sparse-checkout set "${NAMES[@]/#/stations/}" > /dev/null 2>&1
else
    H_SAY "Couldn't reach the online registry ($MAKERY_REGISTRY). Nothing was changed."
    exit 1
fi

# A script is anything that can run: shell, python, make, or a file with a shebang.
is_script() {
    case "$1" in
        *.sh | *.bash | *.zsh | *.py | *.mk | */Makefile | *.pl | *.rb | *.js | *.ts) return 0 ;;
    esac
    head -c 2 "$1" 2>/dev/null | grep -q '^#!'
}

REFUSED=0
mkdir -p "$OFFLINE_REGISTRY/stations"

for name in "${NAMES[@]}"; do
    src="$TMP_DIR/stations/$name"
    if [ ! -d "$src" ]; then
        H_SAY "✗ $name: not in the online registry."
        REFUSED=1
        continue
    fi

    hits=""
    while IFS= read -r file; do
        is_script "$file" || continue
        found=$(grep -nI '' "$file" 2>/dev/null \
            | sed -E 's#^([0-9]+:)[[:space:]]*(\#|//).*$#\1#; s#[[:space:]]\#.*$##; s#^([0-9]+:)#\1 #' \
            | grep -E "^[0-9]+:.*($DANGER)")
        [ -n "$found" ] || continue
        while IFS= read -r line; do
            hits+="    ${file#"$src"/}:$line"$'\n'
        done <<< "$found"
    done < <(find "$src" -type f | sort)

    # Show the first 20 hits; a big station can have hundreds.
    count=$(printf '%s' "$hits" | grep -c '^')
    shown=$(printf '%s' "$hits" | head -20)
    [ "$count" -gt 20 ] && shown+=$'\n'"    ... and $((count - 20)) more"
    [ -n "$hits" ] && shown+=$'\n'

    if [ -n "$hits" ] && [ "$FORCE" != 1 ]; then
        H_SAY "✗ $name: refused. These lines reach the network or install software:"
        printf '%s' "$shown"
        if [ -d "$OFFLINE_REGISTRY/stations/$name" ]; then
            H_SAY "  The copy already in the offline registry stays as it was."
        fi
        H_SAY "  Trust it anyway? Run: bake safe $name --force"
        REFUSED=1
        continue
    fi

    if [ -n "$hits" ]; then
        H_SAY "! $name: added with --force, despite these lines:"
        printf '%s' "$shown"
    else
        H_SAY "✓ $name: no network or install commands found."
    fi
    rm -rf "${OFFLINE_REGISTRY:?}/stations/$name"
    cp -R "$src" "$OFFLINE_REGISTRY/stations/$name"
done

H_SAY "Offline registry: $OFFLINE_REGISTRY/stations"
H_LINE
exit $REFUSED
