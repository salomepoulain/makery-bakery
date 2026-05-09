#!/bin/bash
# ============================================================================
#  LINE COOK CONTRACT: HIRED (Setup Script)
# ============================================================================
# This script is executed exactly once when the Head Chef hires this Line Cook
# using `bake first <this_cook>`.
#
# Use this script to set up local environments, download dependencies, etc.
# You can SAY during setup using SAY (shown with the cook's identity):
#   SAY "Setting up my station and sharpening my knives..."

source "$(dirname "${BASH_SOURCE[0]}")/../personality.sh"

# SAY "Setting up my station and sharpening my knives..."

# Example:
# if [ ! -d ".venv" ]; then
#     python -m venv .venv
# fi
