#!/bin/bash
# ============================================================================
#  HEAD CHEF: REQUEST (Sync .makery stations with the cloud registry)
# ============================================================================
# Detects changes to local .makery/stations and creates a PR on your registry
# (MAKERY_REGISTRY, see ../registry.sh)
# Usage: ./request.sh [--dry-run]

set -e

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

# Parse args
DRY_RUN=false
{ [ "$1" = "--dry-run" ] || [ "$1" = "-n" ]; } && DRY_RUN=true

if [ "$DRY_RUN" = true ]; then
    H_STARTER "SENDING BAKE REQUEST (DRY RUN)"
else
    H_STARTER "SENDING BAKE REQUEST"
fi

# Verify git repo
REPO_ROOT=$(find_project_root) || {
    H_SAY "Error: .makery folder not found"
    exit 1
}

# Config
# shellcheck source=../registry.sh
source "$(dirname "${BASH_SOURCE[0]}")/../registry.sh"
if [ "$REGISTRY_URL" != "https://github.com/$MAKERY_REGISTRY" ]; then
    H_SAY "Error: bake request opens a pull request on GitHub, so MAKERY_REGISTRY must be owner/repo (now: $MAKERY_REGISTRY)"
    exit 1
fi
STATIONS_REPO="$REGISTRY_URL"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Temp dir for comparisons
TEMP_DIR="/tmp/makery-sync-$$"
mkdir -p "$TEMP_DIR"
trap 'rm -rf "$TEMP_DIR"' EXIT

# Helper: Show file changes
# Optional args:
#   $4: no_deletions (true/false, default false) - skip deleted files check
#   $5: exclude_name (pattern) - skip files where relative path starts with this name
show_changes() {
    local label="$1"
    local local_dir="$2"
    local cloud_dir="$3"
    local no_deletions="${4:-false}"
    local exclude_name="${5:-}"
    local has_changes=0

    [ -d "$local_dir" ] || return 1

    echo "$label:"

    # Files in local but not in cloud (new)
    while IFS= read -r f; do
        rel="${f#"$local_dir"/}"
        # Skip if matches exclude pattern (first path component)
        if [ -n "$exclude_name" ] && [[ "$rel" =~ ^$exclude_name/ ]]; then
            continue
        fi
        [ ! -f "$cloud_dir/$rel" ] && echo "  NEW: $rel" && has_changes=1
    done < <(find "$local_dir" -type f 2>/dev/null)

    # Files that differ
    while IFS= read -r f; do
        rel="${f#"$local_dir"/}"
        # Skip if matches exclude pattern
        if [ -n "$exclude_name" ] && [[ "$rel" =~ ^$exclude_name/ ]]; then
            continue
        fi
        cloud_f="$cloud_dir/$rel"
        [ -f "$cloud_f" ] && ! diff -q "$f" "$cloud_f" >/dev/null 2>&1 && echo "  MODIFIED: $rel" && has_changes=1
    done < <(find "$local_dir" -type f 2>/dev/null)

    # Files in cloud but not local (deleted) - only if not no_deletions
    if [ "$no_deletions" != "true" ]; then
        while IFS= read -r f; do
            rel="${f#"$cloud_dir"/}"
            [ ! -f "$local_dir/$rel" ] && echo "  DELETED: $rel" && has_changes=1
        done < <(find "$cloud_dir" -type f 2>/dev/null)
    fi

    [ $has_changes -eq 1 ] && return 0 || return 1
}

# Prepare a work clone on the stable sync branch.
# Writes "update:<pr#>" or "create" into <work_dir>/.sync-mode for the caller.
prepare_branch() {
    local repo_slug="$1"
    local repo_url="$2"
    local push_url="$3"
    local branch="$4"
    local work_dir="$5"

    git clone "$repo_url" "$work_dir" 2>/dev/null || return 1
    (
        cd "$work_dir" || exit 1
        local existing_pr
        # Only your own PR: everyone pushing from a fork uses this same branch name.
        existing_pr=$(gh pr list --repo "$repo_slug" --author "@me" --head "$branch" --state open --json number -q '.[0].number' 2>/dev/null)

        if [ -n "$existing_pr" ] && git fetch "$push_url" "$branch:$branch" >/dev/null 2>&1; then
            git checkout "$branch" >/dev/null 2>&1
            echo "update:$existing_pr" > .sync-mode
        else
            git checkout -b "$branch" origin/main >/dev/null 2>&1
            echo "create" > .sync-mode
        fi
    )
}

# Clone cloud repos for comparison
H_SAY "Cloning cloud repo..."
git clone --depth 1 "$STATIONS_REPO" "$TEMP_DIR/stations" 2>/dev/null || { H_SAY "Failed to clone $MAKERY_REGISTRY"; exit 1; }

LOCAL_STATIONS="$REPO_ROOT/.makery/stations"
CLOUD_STATIONS="$TEMP_DIR/stations/stations"


# ============================================================================
# PROCESS STATIONS
# ============================================================================
H_SAY "=== STATIONS ==="

if show_changes "Comparing stations" "$LOCAL_STATIONS" "$CLOUD_STATIONS" true "_empty_station"; then
    if [ "$DRY_RUN" = true ]; then
        H_SAY "[DRY RUN] Would create or update PR on branch sync/stations"
    else
        BRANCH="sync/stations"
        WORK_STATIONS="$TEMP_DIR/stations-work"

        # Push straight to the registry if you can write to it. Otherwise
        # push to your fork of it (made once) and open the PR from there.
        ME=$(gh api user --jq .login 2>/dev/null) || { H_SAY "Not logged in to GitHub. Run: gh auth login"; exit 1; }
        PERM=$(gh repo view "$MAKERY_REGISTRY" --json viewerPermission --jq .viewerPermission 2>/dev/null)
        case "$PERM" in
            ADMIN|MAINTAIN|WRITE)
                PUSH_REPO="$MAKERY_REGISTRY"
                PR_HEAD="$BRANCH"
                ;;
            *)
                PUSH_REPO="$ME/${MAKERY_REGISTRY#*/}"
                if ! gh repo view "$PUSH_REPO" >/dev/null 2>&1; then
                    H_SAY "You can't write to $MAKERY_REGISTRY, so making your fork $PUSH_REPO..."
                    gh repo fork "$MAKERY_REGISTRY" --clone=false --remote=false >/dev/null 2>&1 \
                        || { H_SAY "Couldn't fork $MAKERY_REGISTRY"; exit 1; }
                fi
                PARENT=$(gh repo view "$PUSH_REPO" --json parent --jq '.parent.owner.login + "/" + .parent.name' 2>/dev/null)
                if [ "$PARENT" != "$MAKERY_REGISTRY" ]; then
                    H_SAY "Error: $PUSH_REPO exists but isn't a fork of $MAKERY_REGISTRY"
                    exit 1
                fi
                PR_HEAD="$ME:$BRANCH"
                ;;
        esac
        PUSH_URL="https://github.com/$PUSH_REPO.git"

        prepare_branch "$MAKERY_REGISTRY" "$STATIONS_REPO" "$PUSH_URL" "$BRANCH" "$WORK_STATIONS" \
            || { H_SAY "Failed to prepare work clone"; exit 1; }

        MODE=$(cat "$WORK_STATIONS/.sync-mode"); rm "$WORK_STATIONS/.sync-mode"
        cd "$WORK_STATIONS" || exit 1

        mkdir -p stations
        for station_dir in "$LOCAL_STATIONS"/*/; do
            [ -d "$station_dir" ] || continue
            station_name=$(basename "$station_dir")
            [ "$station_name" = "_empty_station" ] && continue
            rm -rf "stations/$station_name"
            cp -r "$station_dir" "stations/$station_name"
            git add -A "stations/$station_name"
        done

        if [ "$(git diff --cached --name-only | grep -v "^stations/" | grep -c .)" -gt 0 ]; then
            H_SAY "Error: Non-stations files detected. Aborting."
            exit 1
        fi

        if git diff --cached --quiet; then
            H_SAY "Branch already matches local state, nothing to push"
        else
            git commit -m "Sync stations updates ($TIMESTAMP)" >/dev/null
            git push --force "$PUSH_URL" "$BRANCH" >/dev/null 2>&1 \
                || { H_SAY "Push to $PUSH_REPO failed"; exit 1; }

            case "$MODE" in
                update:*)
                    H_SAY "✓ Updated existing PR #${MODE#update:}"
                    ;;
                create)
                    PR=$(gh pr create --repo "$MAKERY_REGISTRY" \
                        --title "Sync stations updates from $ME" \
                        --body "Automated sync of stations changes, sent with \`bake request\`." \
                        --head "$PR_HEAD" --base main 2>&1)
                    H_SAY "✓ PR: $PR"
                    ;;
            esac
        fi
    fi
else
    H_SAY "No changes"
fi

H_FINISHED
