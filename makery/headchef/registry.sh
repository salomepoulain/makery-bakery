#!/bin/bash
# ============================================================================
#  HEAD CHEF: REGISTRY (where stations come from)
# ============================================================================
# A registry is a git repo with a stations/<name>/ folder per station.
# Pick yours with MAKERY_REGISTRY, as a GitHub owner/repo (e.g. in ~/.zshrc):
#   export MAKERY_REGISTRY=jan/my-stations
# A full git URL or a local path works too, except for `bake request`, which
# opens pull requests on GitHub and so needs owner/repo.
# shellcheck disable=SC2034 # used by the orders that source this file

MAKERY_REGISTRY="${MAKERY_REGISTRY:-salomepoulain/makery-stations}"

case "$MAKERY_REGISTRY" in
    */*/* | *:*) REGISTRY_URL="$MAKERY_REGISTRY" ;;
    *) REGISTRY_URL="https://github.com/$MAKERY_REGISTRY" ;;
esac
