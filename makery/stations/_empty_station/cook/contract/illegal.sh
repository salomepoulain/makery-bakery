#!/bin/bash
# ============================================================================
#  LINE COOK CONTRACT: ILLEGAL (Going Shady - optional)
# ============================================================================
# This script is OPTIONAL. Delete this file if your station has nothing to
# react to when the project goes shady.
#
# If present, it runs after `bake shady` has already stashed this station's
# contraband into .shadow/ (see workbench/.contraband). Use it when stashing
# alone isn't enough - when the station needs to reconfigure itself now
# that some of its files live in the stash instead of the working tree
# (e.g. pointing a tool's own config at the new symlinked location).
#
# The Head Chef exports two variables before running this:
#   REPO_ROOT   - the project root
#   SHADOW_DIR  - where this project's stash actually lives
#              ($REPO_ROOT/__stash__ symlinks here)
#
# You can SAY during this step (set MAKERY_QUIET_SHADY=1 upstream to
# suppress announcements when this runs as part of an automatic sweep,
# rather than a deliberate `bake shady`):
#   SAY "Reacting to going shady"

source "$(dirname "${BASH_SOURCE[0]}")/../personality.sh"

# SAY "Reacting to going shady"

# Example: point a tool's own config at the stash now that a folder of
# its state has moved there.
# CONFIG_FILE="$REPO_ROOT/.mytool/config.json"
# if [ -f "$CONFIG_FILE" ]; then
#     jq --arg dir "$SHADOW_DIR" '.dataDir = $dir' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" \
#         && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
# fi
