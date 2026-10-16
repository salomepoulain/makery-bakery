#!/usr/bin/env bash
# ============================================================================
#  HEAD CHEF: PERSONALITY & FORMATTING HELPERS
# ============================================================================


# --- Colors & Styling ---
# Rainbow spectrum
export RED='\033[1;31m'
export ORANGE='\033[38;5;208m'
export YELLOW='\033[1;33m'
export GREEN='\033[1;32m'
export CYAN='\033[1;36m'
export BLUE='\033[1;34m'
export PURPLE='\033[1;35m'
export MAGENTA='\033[1;35m'

# Neutrals
export BLACK='\033[1;30m'
export WHITE='\033[1;37m'
export GRAY='\033[1;90m'
export BROWN='\033[38;5;94m'

# Text styling
export BOLD='\033[1m'
export DIM='\033[2m'
export ITALIC='\033[3m'
export NC='\033[0m'

hex_to_truecolor() {
    local hex=${1#\#} 
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    echo -e "\033[38;2;${r};${g};${b}m"
}


# SELECT IDENTITY
# -----------------------------------------------------
HC_ICON="𜴜"
HC_NAME="headchef"

if [[ "${HC_LIGHT_BG:-0}" == "1" ]]; then
    HC_COLOR=$(hex_to_truecolor "#AA7942")
else
    HC_COLOR=$(hex_to_truecolor "#F5DCB4") #$'\033[38;5;230m' AA7942
fi

_HC_ID_VISIBLE_OFFSET=1
# ------------------------------------------------------

# Fixed column width for the icon+name slot; pad with spaces when shorter
_HC_PREFIX_WIDTH=12

_calc_hc_id_visible_len() {
    echo $((${#HC_ICON} + ${#HC_NAME} + 1 + ${_HC_ID_VISIBLE_OFFSET:-0}))
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

# --- Head Chef Functions ---
H_STARTER() {
    local rule rule_thin
    _term_cols >/dev/null
    _rule_into rule "☰"
    _rule_into rule_thin "—"
    echo -e "${HC_COLOR}${rule}${NC}"
    echo -e "${HC_COLOR}  $1${NC}"
    echo -e "${HC_COLOR}${rule_thin}${NC}"
}

H_FINISHED() {
    H_LINE
    # local rule cols
    # cols=$(_term_cols)
    # rule=$(awk -v n="$cols" 'BEGIN{while(i++<n)printf"☰";print""}')
    # rule_thin=$(awk -v n="$cols" 'BEGIN{while(i++<n)printf"―";print""}')
    # echo -e "${HC_COLOR}${rule_thin}${NC}"
    # echo -e "${HC_COLOR}  BAKE FINISHED${NC}"
    # echo -e "${HC_COLOR}${rule}${NC}"
}

H_LINE() {
    local rule
    _term_cols >/dev/null
    _rule_into rule "☰"
    echo -e "${HC_COLOR}${rule}${NC}"
}

H_SAY() {
    local cols msg_width msg_start_col pad spaces cont_indent id_visible_len
    _term_cols >/dev/null; cols=$MAKERY_COLS
    id_visible_len=$(( ${#HC_ICON} + ${#HC_NAME} + 1 + ${_HC_ID_VISIBLE_OFFSET:-0} ))
    msg_start_col=$(( _HC_PREFIX_WIDTH + 3 ))
    msg_width=$(( cols - msg_start_col ))
    [[ "$msg_width" -lt 20 ]] && msg_width=20

    pad=$(( _HC_PREFIX_WIDTH - id_visible_len ))
    printf -v spaces '%*s' "$pad" ''

    # Most messages fit on one line: print them straight away, no fold.
    if (( ${#1} <= msg_width )) && [[ "$1" != *$'\n'* ]]; then
        echo -e "  ${HC_COLOR}${HC_ICON} $HC_NAME:${NC}${spaces} ${ITALIC}${DIM}${1}${NC}"
        return
    fi

    printf -v cont_indent '%*s' "$msg_start_col" ''
    local first=1
    echo "$1" | fold -sw "$msg_width" | while IFS= read -r line; do
        if [[ "$first" -eq 1 ]]; then
            echo -e "  ${HC_COLOR}${HC_ICON} $HC_NAME:${NC}${spaces} ${ITALIC}${DIM}${line}${NC}"
            first=0
        else
            echo -e "${cont_indent}${ITALIC}${DIM}${line}${NC}"
        fi
    done
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
}
