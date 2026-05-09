#!/usr/bin/env bash
# shellcheck disable=SC2034
# Provider switching recipe for Claude Code
# Usage: bake call s=claude d=models

source "$(dirname "${BASH_SOURCE[0]}")/../personality.sh"

# Core directories
REPOSITORY="$(git rev-parse --show-toplevel 2>/dev/null)"
STATION_DIR="$(dirname "${BASH_SOURCE[0]}")/../.."
PANTRY_DIR="$STATION_DIR/workbench/pantry"
