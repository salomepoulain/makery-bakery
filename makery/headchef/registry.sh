#!/bin/bash
# ============================================================================
#  HEAD CHEF: REGISTRY (where stations come from)
# ============================================================================
# A registry is a collection of stations/<name>/ folders. It is either online
# (a git repo, cloned when needed) or offline (a plain folder on disk).
#
# Pick an online one with MAKERY_REGISTRY, as a GitHub owner/repo (e.g. in ~/.zshrc):
#   export MAKERY_REGISTRY=jan/my-stations
# A full git URL or a local path works too, except for `bake request`, which
# opens pull requests on GitHub and so needs owner/repo.
#
# The offline registry is always ~/.makery-bakery. `bake safe` fills it, and an
# offline bake (MAKERY_OFFLINE=1) hires from nowhere else.
# shellcheck disable=SC2034 # used by the orders that source this file

OFFLINE_REGISTRY="$HOME/.makery-bakery"

if [ "${MAKERY_OFFLINE:-}" = 1 ]; then
    MAKERY_REGISTRY="$OFFLINE_REGISTRY"
    REGISTRY_URL="$OFFLINE_REGISTRY"
# >>> online-only
else
    MAKERY_REGISTRY="${MAKERY_REGISTRY:-salomepoulain/makery-stations}"
    case "$MAKERY_REGISTRY" in
        */*/* | *:*) REGISTRY_URL="$MAKERY_REGISTRY" ;;
        *) REGISTRY_URL="https://github.com/$MAKERY_REGISTRY" ;;
    esac
# <<< online-only
fi
