#!/usr/bin/env bash
# shellcheck disable=SC2034
# ============================================================================
#  LINE COOK: PERSONALITY & IDENTITY
# ============================================================================

# --- Colors & Styling ---
# Rainbow spectrum
RED='\033[1;31m'
ORANGE='\033[38;5;208m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
MAGENTA='\033[1;35m'

# Neutrals
BLACK='\033[1;30m'
WHITE='\033[1;37m'
GRAY='\033[1;90m'
BROWN='\033[38;5;94m'

# Text styling
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
NC='\033[0m'


hex_to_truecolor() {
    local hex=${1#\#} 
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    echo -e "\033[38;2;${r};${g};${b}m"
}


# SELECT IDENTITY (Override these in your station)
# -----------------------------------------------------
COOK_ICON="✦" # find at https://emojidb.org/
# COOK_NAME is auto-derived from parent folder name (e.g., stations/claude/ → "claude")
COOK_NAME="my-station"
COOK_COLOR=$(hex_to_truecolor "#BBBBBB")
#COOK_COLOR="$CYAN"

_HC_ID_VISIBLE_OFFSET=0
# ------------------------------------------------------


# Fixed column width for the icon+name slot; pad with spaces when shorter
_HC_PREFIX_WIDTH=12

_calc_hc_id_visible_len() {
    echo $((${#COOK_ICON} + ${#COOK_NAME} + 1 + ${_HC_ID_VISIBLE_OFFSET:-0}))
}

# --- Helpers ---
_term_cols() {
    # Measured once, then reused: MAKERY_COLS is exported, so nested orders
    # and station menus don't each start stty again for every line.
    if [[ -z "${MAKERY_COLS:-}" ]]; then
        local size
        size=$(stty size 2>/dev/null)
        MAKERY_COLS=${size##* }
        [[ "$MAKERY_COLS" =~ ^[0-9]+$ ]] || MAKERY_COLS=80
        export MAKERY_COLS
    fi
    echo "$MAKERY_COLS"
}

# Put a full-width line of character $2 into variable $1 (bash only, no awk).
_rule_into() {
    printf -v "$1" '%*s' "$MAKERY_COLS" ''
    printf -v "$1" '%s' "${!1// /$2}"
}

# A short pause after each printed line, so output scrolls in line by line.
# MAKERY_LINE_DELAY is seconds per line (0 turns it off). Only on a terminal:
# logs, pipes and agents get the output at full speed. bash's built-in sleep
# (where it exists) keeps the pause exactly as long as asked; otherwise the
# sleep program is used, which adds a few milliseconds.
enable -f sleep sleep 2>/dev/null || true
_pace() {
    [[ -t 1 ]] || return 0
    local d="${MAKERY_LINE_DELAY:-0.005}"
    [[ "$d" == 0 || "$d" == 0.0 ]] && return 0
    sleep "$d"
}

SAY() {
    local cols msg_width msg_start_col pad spaces cont_indent id_visible_len
    _term_cols >/dev/null; cols=$MAKERY_COLS
    id_visible_len=$(( ${#COOK_ICON} + ${#COOK_NAME} + 1 + ${_HC_ID_VISIBLE_OFFSET:-0} ))
    msg_start_col=$(( _HC_PREFIX_WIDTH + 3 ))
    msg_width=$(( cols - msg_start_col ))
    [[ "$msg_width" -lt 20 ]] && msg_width=20

    pad=$(( _HC_PREFIX_WIDTH - id_visible_len ))
    printf -v spaces '%*s' "$pad" ''

    # Most messages fit on one line: print them straight away, no fold.
    if (( ${#1} <= msg_width )) && [[ "$1" != *$'\n'* ]]; then
        echo -e "  ${COOK_COLOR}${COOK_ICON} $COOK_NAME:${NC}${spaces} ${ITALIC}${DIM}${1}${NC}"
        _pace
        return
    fi

    printf -v cont_indent '%*s' "$msg_start_col" ''
    local first=1
    echo "$1" | fold -sw "$msg_width" | while IFS= read -r line; do
        if [[ "$first" -eq 1 ]]; then
            echo -e "  ${COOK_COLOR}${COOK_ICON} $COOK_NAME:${NC}${spaces} ${ITALIC}${DIM}${line}${NC}"
            first=0
        else
            echo -e "${cont_indent}${ITALIC}${DIM}${line}${NC}"
        fi
    done
    _pace
}

ITEM() {
    local cols cmd_width msg_start_col desc_width
    _term_cols >/dev/null; cols=$MAKERY_COLS
    cmd_width=28
    msg_start_col=$(( 4 + cmd_width + 2 ))
    desc_width=$(( cols - msg_start_col ))
    [[ "$desc_width" -lt 10 ]] && desc_width=10

    # Most descriptions fit on one line: print them straight away, no fold.
    if (( ${#2} <= desc_width )); then
        printf "  %-${cmd_width}s  %s\n" "$1" "$2"
        _pace
        return
    fi

    local cont_indent
    printf -v cont_indent '%*s' "$msg_start_col" ''

    local desc_line first=1
    while IFS= read -r desc_line; do
        if [[ $first -eq 1 ]]; then
            printf "  %-${cmd_width}s  %s\n" "$1" "$desc_line"
            first=0
        else
            printf "%s  %s\n" "$cont_indent" "$desc_line"
        fi
    done <<< "$(printf '%s' "$2" | fold -sw "$desc_width")"
    _pace
}

STARTER() {
    local rule rule_thin
    _term_cols >/dev/null
    _rule_into rule "━"
    _rule_into rule_thin "—"
    echo -e "${COOK_COLOR}${rule}${NC}"
    echo -e "${COOK_COLOR}  $1${NC}"
    echo -e "${COOK_COLOR}${rule_thin}${NC}"
    _pace
}

FINISHED() {
    local rule rule_thin
    _term_cols >/dev/null
    _rule_into rule "━"
    _rule_into rule_thin "—"
    echo -e "${COOK_COLOR}${rule_thin}${NC}"
    echo -e "${COOK_COLOR}  BAKE FINISHED${NC}"
    echo -e "${COOK_COLOR}${rule}${NC}"
    _pace
}

LINE() {
    local rule
    _term_cols >/dev/null
    _rule_into rule "━"
    echo -e "${COOK_COLOR}${rule}${NC}"
    _pace
}
