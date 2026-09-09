#!/usr/bin/env bash
# ============================================================================
#  LINE COOK SKILL: EXAMPLE
# ============================================================================
# One skill = one shell script, wired up in menu.mk as a `bake call` target.
# Usage: bake call s=<station> d=example

source "$(dirname "${BASH_SOURCE[0]}")/../personality.sh"

# SAY "Doing the thing"
