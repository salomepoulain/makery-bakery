#!/bin/bash
# ============================================================================
#  HEAD CHEF: ACCEPT (Merge PRs and create tarball from updated .makery)
# ============================================================================
# Finds PRs with sync/ prefix, confirms each merge, and archives .makery
# Usage: ./accept.sh

set -e

# Validate this script before proceeding
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
if shellcheck -x --exclude=SC1091 "$SCRIPT_PATH" >/dev/null 2>&1; then
    :
else
    echo "Error: shellcheck validation failed"
    exit 1
fi

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

H_STARTER "ACCEPTING MAKERY UPDATES"

# Verify git repo
REPO_ROOT=$(find_project_root) || {
    H_SAY "Error: .makery folder not found"
    exit 1
}

# ============================================================================
# AUTHORIZATION CHECK
# ============================================================================
# Verify current user has permission to merge PRs
CURRENT_USER=$(gh api user --jq '.login' 2>/dev/null) || {
    H_SAY "Error: not authenticated with GitHub (run: gh auth login)"
    exit 1
}

# Config
STATIONS_REPO="salomepoulain/makery-stations"
REPO_OWNER="salomepoulain"

# Check permissions for stations repo
PERM=$(gh repo view "$STATIONS_REPO" --json viewerPermission --jq '.viewerPermission' 2>/dev/null) || {
    H_SAY "Error: cannot access repo $STATIONS_REPO (check permissions and authentication)"
    exit 1
}

case "$PERM" in
    ADMIN|MAINTAIN) ;;
    *)
        H_SAY "Error: you ($CURRENT_USER) do not have admin/maintain rights on $STATIONS_REPO"
        H_SAY "Only $REPO_OWNER can bake in changes. Contact the repo owner."
        exit 1
        ;;
esac

H_SAY "✓ Authorized as $CURRENT_USER (owner)"

# Track partial acceptances
declare -A PARTIAL_REPOS
declare -A ACCEPTED_FILES_MAP

# Helper: Draw the confirm prompt with the given selection
_draw_confirm_box() {
    local prompt="$1"
    local selected="$2"  # 0=Accept, 1=Open, 2=Reject
    local rule cols
    local accept_marker open_marker reject_marker
    local accept_style open_style reject_style

    cols=$(_term_cols)
    rule=$(awk -v n="$cols" 'BEGIN{while(i++<n)printf"━";print""}')

    case "$selected" in
        0)
            accept_marker="❯"; accept_style="${GREEN}${BOLD}"
            open_marker=" "; open_style="${DIM}"
            reject_marker=" "; reject_style="${DIM}"
            ;;
        1)
            accept_marker=" "; accept_style="${DIM}"
            open_marker="❯"; open_style="${BOLD}"
            reject_marker=" "; reject_style="${DIM}"
            ;;
        2)
            accept_marker=" "; accept_style="${DIM}"
            open_marker=" "; open_style="${DIM}"
            reject_marker="❯"; reject_style="${RED}${BOLD}"
            ;;
    esac

    echo -e "${HC_COLOR}${rule}${NC}"
    printf "  ${BOLD}%-*s${NC}\n" $((cols - 2)) "$prompt"
    echo -e ""
    printf "  ${accept_style}${accept_marker}%-*s${NC}\n" $((cols - 4)) " Accept"
    printf "  ${open_style}${open_marker}%-*s${NC}\n" $((cols - 4)) " Open in VS Code"
    printf "  ${reject_style}${reject_marker}%-*s${NC}\n" $((cols - 4)) " Reject"
    echo -e ""
    printf "  ${DIM}%-*s${NC}\n" $((cols - 2)) "↑/↓ to navigate, Enter to confirm, y/n/o for quick choice"
    echo -e "${HC_COLOR}${rule}${NC}"
}

# Helper: Confirm action with arrow-key navigation (returns 0=Accept, 1=Open, 2=Reject)
confirm() {
    local prompt="$1"
    local selected=0  # 0=Accept (default), 1=Open, 2=Reject
    local key

    echo ""
    tput civis 2>/dev/null || true
    _draw_confirm_box "$prompt" "$selected"

    while true; do
        IFS= read -rsn1 key < /dev/tty
        if [[ $key == $'\e' ]]; then
            IFS= read -rsn2 -t 0.05 key < /dev/tty || true
            case "$key" in
                '[A'|'[D') selected=$(( (selected - 1 + 3) % 3 )); printf '\033[9A'; _draw_confirm_box "$prompt" "$selected" ;;
                '[B'|'[C') selected=$(( (selected + 1) % 3 )); printf '\033[9A'; _draw_confirm_box "$prompt" "$selected" ;;
            esac
        elif [[ $key == "" ]]; then
            tput cnorm 2>/dev/null || true
            echo ""
            return "$selected"
        elif [[ $key == "y" || $key == "Y" ]]; then
            tput cnorm 2>/dev/null || true
            echo ""
            return 0
        elif [[ $key == "n" || $key == "N" ]]; then
            tput cnorm 2>/dev/null || true
            echo ""
            return 2
        elif [[ $key == "o" || $key == "O" ]]; then
            tput cnorm 2>/dev/null || true
            echo ""
            return 1
        elif [[ $key == "j" ]]; then
            selected=$(( (selected + 1) % 3 )); printf '\033[9A'; _draw_confirm_box "$prompt" "$selected"
        elif [[ $key == "k" ]]; then
            selected=$(( (selected - 1 + 3) % 3 )); printf '\033[9A'; _draw_confirm_box "$prompt" "$selected"
        fi
    done
}

# Helper: Colorize diff with full-width line backgrounds (like VS Code)
# Long lines wrap and continue with the same +/- marker
colorize_diff() {
    local cols
    cols=$(stty size 2>/dev/null | awk '{print $2}')
    [[ "$cols" =~ ^[0-9]+$ ]] || cols=120

    awk -v cols="$cols" '
        BEGIN {
            GREEN = "\033[97;48;2;0;40;0m"
            RED   = "\033[97;48;2;60;0;0m"
            CTX   = "\033[37;48;2;20;20;20m"
            RESET = "\033[0m"
        }
        function pad(s,    n) {
            n = cols - length(s)
            if (n < 0) n = 0
            return s sprintf("%*s", n, "")
        }
        function wrap(marker, body, color,    chunk, width, line) {
            width = cols - 8
            if (width < 20) width = 20
            chunk = substr(body, 1, width)
            line = chunk sprintf("%*s", width - length(chunk), "")
            printf "%s%s%s%s\n", color, marker, line, RESET
        }
        /^diff |^index |^new file|^deleted file|^similarity|^\+\+\+|^---/ { next }
        /^@@/    { printf "\033[1;35m%s\033[0m\n", pad($0); next }
        /^\+/    { wrap("+", substr($0, 2), GREEN); next }
        /^-/     { wrap("-", substr($0, 2), RED);   next }
                 { print }
    '
}

# Helper: Find and process sync PRs for a repo
process_repo() {
    local repo_name="$1"

    # H_SAY "=== $repo_name ==="

    # Find all open PRs with sync/ prefix
    PR_NUMS=$(gh pr list --repo "$repo_name" --state open --json number,title --jq '.[] | select(.title | startswith("Sync")) | .number' 2>/dev/null || true)

    if [ -z "$PR_NUMS" ]; then
        H_SAY "No open sync/ PRs found"
        return 0
    fi

    local merged_count=0

    while IFS= read -r pr_num; do
        [ -z "$pr_num" ] && continue

        # Get PR title
        pr_title=$(gh pr view "$pr_num" --repo "$repo_name" --json title --jq '.title' 2>/dev/null || echo "PR #$pr_num")

        # Show PR details
        # echo ""
        # echo -e "${HC_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        # H_LINE
        echo ""
        echo -e "${HC_COLOR}PR $repo_name #$pr_num: $pr_title${NC}"
        echo ""
        # H_LINE
        # echo -e "${HC_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        # echo ""

        # Clone the cloud repo and checkout PR for proper side-by-side diff
        PR_WORK="/tmp/pr-${pr_num}-$$"
        rm -rf "$PR_WORK"
        # H_SAY "Fetching PR contents..."
        git clone --quiet "https://github.com/$repo_name" "$PR_WORK" 2>/dev/null || {
            H_SAY "Failed to clone $repo_name"
            continue
        }

        cd "$PR_WORK" || continue
        BASE_BRANCH=$(gh pr view "$pr_num" --repo "$repo_name" --json baseRefName --jq '.baseRefName' 2>/dev/null || echo "main")

        # Fetch the PR head as a local branch
        if ! git fetch origin "pull/$pr_num/head:pr-$pr_num" --quiet 2>/dev/null; then
            H_SAY "Failed to fetch PR #$pr_num"
            cd "$REPO_ROOT" || true
            continue
        fi
        git checkout -q "pr-$pr_num" 2>/dev/null || {
            H_SAY "Failed to checkout pr-$pr_num"
            cd "$REPO_ROOT" || true
            continue
        }

        # Get list of changed files
        CHANGED_FILES=$(git diff --name-only "origin/$BASE_BRANCH"...HEAD)

        # Save before/after versions per file
        BEFORE_DIR="$PR_WORK/.before"
        AFTER_DIR="$PR_WORK/.after"
        mkdir -p "$BEFORE_DIR" "$AFTER_DIR"

        echo -e "${BROWN}Files changed:${NC}"
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            mkdir -p "$BEFORE_DIR/$(dirname "$f")" "$AFTER_DIR/$(dirname "$f")"
            git show "origin/$BASE_BRANCH:$f" > "$BEFORE_DIR/$f" 2>/dev/null || : > "$BEFORE_DIR/$f"
            git show "HEAD:$f" > "$AFTER_DIR/$f" 2>/dev/null || : > "$AFTER_DIR/$f"

            # Compact summary per file
            stats=$(git diff --shortstat "origin/$BASE_BRANCH"...HEAD -- "$f" 2>/dev/null | sed 's/^ *//')
            echo -e "  ${HC_COLOR}$f${NC}  ${DIM}$stats${NC}"
        done <<< "$CHANGED_FILES"

        H_LINE

        # Review each file individually
        declare -a accepted_files rejected_files
        local file_idx=0
        local total_files
        total_files=$(echo "$CHANGED_FILES" | grep -c .)

        while IFS= read -r f; do
            [ -z "$f" ] && continue
            ((file_idx++))

            # File header with counter
            echo -e "  ${BOLD}[$file_idx/$total_files]${NC}  ${HC_COLOR}$f${NC}"

            # Show terminal diff for this file
            git --no-pager diff --no-color "origin/$BASE_BRANCH"...HEAD -- "$f" | tail -n +5 | colorize_diff
            echo ""

            # Ask to accept/reject/open this file (loop until decided)
            local after_abs before_abs choice
            after_abs="$(cd "$AFTER_DIR" && pwd)/$f"
            before_abs="$(cd "$BEFORE_DIR" && pwd)/$f"

            while true; do
                confirm "Accept this file?"
                choice=$?
                case "$choice" in
                    0) accepted_files+=("$f"); break ;;
                    1) code --diff "$before_abs" "$after_abs" >/dev/null 2>&1 & wait $!; tput clear 2>/dev/null || true ;;
                    2) rejected_files+=("$f"); break ;;
                esac
            done
        done <<< "$CHANGED_FILES"

        cd "$REPO_ROOT" || true

        # Summary
        local accepted_count=${#accepted_files[@]}
        local rejected_count=${#rejected_files[@]}

        if [ "$accepted_count" -gt 0 ]; then
            H_SAY "✓ $accepted_count accepted  ✗ $rejected_count rejected"
        else
            H_SAY "✗ Nothing accepted, skipping PR"
        fi

        # Handle merge based on acceptance
        if [ "$accepted_count" -eq 0 ]; then
            # No files accepted, skip
            continue
        elif [ "$rejected_count" -eq 0 ]; then
            # All files accepted, merge normally
            H_SAY "Merging PR #$pr_num..."
            if gh pr merge "$pr_num" --repo "$repo_name" --squash --auto 2>/dev/null || gh pr merge "$pr_num" --repo "$repo_name" --squash 2>/dev/null; then
                H_SAY "✓ Merged PR #$pr_num"
                ((merged_count++))
            else
                H_SAY "Error merging PR #$pr_num"
            fi
        else
            # Partial acceptance: rewrite PR branch with only accepted files
            H_SAY "Rewriting PR with $accepted_count/$total_files files..."

            SYNC_BRANCH=$(gh pr view "$pr_num" --repo "$repo_name" --json headRefName --jq '.headRefName' 2>/dev/null)
            [ -z "$SYNC_BRANCH" ] && { H_SAY "Error: cannot determine PR branch"; continue; }

            # Restore rejected files to base state
            for rejected_f in "${rejected_files[@]}"; do
                git -C "$PR_WORK" checkout "origin/$BASE_BRANCH" -- "$rejected_f" 2>/dev/null \
                    || git -C "$PR_WORK" rm --cached "$rejected_f" 2>/dev/null || true
            done

            # Stage and commit
            git -C "$PR_WORK" add -A
            if ! git -C "$PR_WORK" diff --cached --quiet; then
                git -C "$PR_WORK" commit -m "Sync partial ($accepted_count/$total_files files accepted)" 2>/dev/null
                git -C "$PR_WORK" push --force-with-lease origin "pr-$pr_num:$SYNC_BRANCH" 2>/dev/null \
                    || { H_SAY "Error: push failed"; continue; }
            fi

            # Merge the rewritten PR
            H_SAY "Merging PR #$pr_num (partial)..."
            if gh pr merge "$pr_num" --repo "$repo_name" --squash --auto 2>/dev/null || gh pr merge "$pr_num" --repo "$repo_name" --squash 2>/dev/null; then
                H_SAY "✓ Merged PR #$pr_num (partial)"
                ((merged_count++))
                # Store which files were accepted for later pull
                PARTIAL_REPOS[$repo_name]=1
                ACCEPTED_FILES_MAP[$repo_name]+=$(printf '%s\n' "${accepted_files[@]}")
            else
                H_SAY "Error merging PR #$pr_num"
            fi
        fi
    done <<< "$PR_NUMS"

    return $merged_count
}

# ============================================================================
# PROCESS REPOS
# ============================================================================
TOTAL_MERGED=0

process_repo "$STATIONS_REPO" "stations" || STATIONS_MERGED=$?
TOTAL_MERGED=$((TOTAL_MERGED + STATIONS_MERGED))

# ============================================================================
# PULL MERGED CHANGES
# ============================================================================
if [ "$TOTAL_MERGED" -gt 0 ]; then
    H_SAY "Pulling merged changes..."
    cd "$REPO_ROOT" || exit 1

    # Pull from cloud repos into local .makery
    TEMP_DIR="/tmp/makery-accept-$$"
    mkdir -p "$TEMP_DIR"
    trap 'rm -rf "$TEMP_DIR"' EXIT

    git clone --depth 1 --quiet "https://github.com/$STATIONS_REPO" "$TEMP_DIR/stations" 2>/dev/null || { H_SAY "Failed to clone makery-stations"; exit 1; }

    # Update local stations
    mkdir -p "$REPO_ROOT/.makery/kitchen/stations"
    if [ "${PARTIAL_REPOS[$STATIONS_REPO]}" = "1" ]; then
        # Partial merge: copy only accepted files
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            mkdir -p "$REPO_ROOT/.makery/kitchen/stations/$(dirname "$f")"
            cp "$TEMP_DIR/stations/stations/$f" "$REPO_ROOT/.makery/kitchen/stations/$f" 2>/dev/null || true
        done <<< "${ACCEPTED_FILES_MAP[$STATIONS_REPO]}"
        H_SAY "✓ Updated stations (partial)"
    else
        if cp -r "$TEMP_DIR/stations/stations"/* "$REPO_ROOT/.makery/kitchen/stations/" 2>/dev/null; then
            H_SAY "✓ Updated stations"
        fi
    fi
else
    H_SAY "No PRs were merged."
fi

H_FINISHED
