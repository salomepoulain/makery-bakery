#!/bin/bash
# ============================================================================
#  HEAD CHEF: RELEASE (Tag makery-bakery and publish a GitHub Release)
# ============================================================================
# Tags current main of makery-bakery with a date-based version and pushes the
# tag. The Build Release workflow (.github/workflows/release.yml) publishes
# the GitHub Release. Same-day re-runs bump a -N suffix.
# Usage: ./release.sh

set -e

# shellcheck source=../personality.sh
source "$(dirname "${BASH_SOURCE[0]}")/../personality.sh"

# An offline bake never talks to GitHub.
if [ "${MAKERY_OFFLINE:-}" = 1 ]; then
    H_SAY "This is an offline bake. 'bake release' needs GitHub, so it's switched off here."
    exit 1
fi

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

H_STARTER "RELEASING MAKERY"

REPO_ROOT=$(find_project_root) || {
    H_SAY "Error: .makery folder not found"
    exit 1
}

MULTI_REPO="salomepoulain/makery-bakery"
ARCHIVE_DIR="$REPO_ROOT/makery-archives"
mkdir -p "$ARCHIVE_DIR"

# ============================================================================
# AUTHORIZATION CHECK
# ============================================================================
CURRENT_USER=$(gh api user --jq '.login' 2>/dev/null) || {
    H_SAY "Error: not authenticated with GitHub (run: gh auth login)"
    exit 1
}

PERM=$(gh repo view "$MULTI_REPO" --json viewerPermission --jq '.viewerPermission' 2>/dev/null) || {
    H_SAY "Error: cannot access $MULTI_REPO"
    exit 1
}
case "$PERM" in
    ADMIN|MAINTAIN) ;;
    *)
        H_SAY "Error: you ($CURRENT_USER) lack admin/maintain rights on $MULTI_REPO"
        exit 1
        ;;
esac
H_SAY "✓ Authorized as $CURRENT_USER"

# ============================================================================
# CLONE
# ============================================================================
TEMP_DIR="/tmp/release-$$"
mkdir -p "$TEMP_DIR"
trap 'rm -rf "$TEMP_DIR"' EXIT

H_SAY "Cloning $MULTI_REPO..."
git clone --quiet "https://github.com/$MULTI_REPO" "$TEMP_DIR/multi" 2>/dev/null || {
    H_SAY "Failed to clone"
    exit 1
}

cd "$TEMP_DIR/multi" || exit 1

# ============================================================================
# VERSION GENERATION (date-based; bumps suffix on same-day re-releases)
# ============================================================================
DATE_VERSION="v$(date +%Y.%m.%d)"
VERSION="$DATE_VERSION"
N=2
while git rev-parse -q --verify "refs/tags/$VERSION" >/dev/null 2>&1; do
    VERSION="${DATE_VERSION}-${N}"
    N=$((N + 1))
done
H_SAY "Version: $VERSION"

# ============================================================================
# TAG & PUSH
# ============================================================================
H_SAY "Tagging main with $VERSION..."
git tag "$VERSION" 2>/dev/null || { H_SAY "Failed to create tag $VERSION"; exit 1; }

H_SAY "Pushing tag..."
git push origin "$VERSION" --quiet 2>/dev/null || { H_SAY "Failed to push tag"; exit 1; }
H_SAY "✓ Tag pushed: https://github.com/$MULTI_REPO/releases/tag/$VERSION"

# ============================================================================
# GENERATE TARBALL (scoped to makery/) & CHECKSUM
# ============================================================================
TARBALL_PATH="$ARCHIVE_DIR/makery-bakery-$VERSION.tar.gz"
CHECKSUM_PATH="$ARCHIVE_DIR/makery-bakery-$VERSION.tar.gz.sha256"

H_SAY "Generating tarball from makery/..."
git -C "$TEMP_DIR/multi" archive --format=tar.gz "$VERSION:makery" -o "$TARBALL_PATH" || { H_SAY "Failed to generate tarball"; exit 1; }

TARBALL_SIZE=$(du -h "$TARBALL_PATH" | cut -f1)
H_SAY "✓ Saved: $TARBALL_PATH ($TARBALL_SIZE)"

H_SAY "Generating checksum..."
sha256sum "$TARBALL_PATH" | awk '{print $1}' > "$CHECKSUM_PATH"
H_SAY "✓ Checksum: $(cat "$CHECKSUM_PATH")"

# ============================================================================
# OFFLINE PACKAGE (for machines that can only download a zip in a browser)
# ============================================================================
# makery-bakery-offline.zip holds one folder, makery-bakery/, with an offline
# bake and every Station from the registry that passes `bake safe`'s scan.
# Unzip it, drag it into your home on the cluster, rename it to .makery-bakery.
OFFLINE_ZIP="$ARCHIVE_DIR/makery-bakery-offline-$VERSION.zip"
OFFLINE_ASSET=()
if command -v zip > /dev/null 2>&1; then
    H_SAY "Building the offline package..."
    PKG_HOME="$TEMP_DIR/offline-home"
    PKG="$PKG_HOME/.makery-bakery"
    mkdir -p "$PKG/stations"

    # The offline bake: the same binary install_bake.sh writes, flipped to offline.
    {
        awk "/^  cat << '__BAKE_HEAD_EOF__'\$/{flag=1;next} /^__BAKE_HEAD_EOF__\$/{flag=0} flag" \
            "$TEMP_DIR/multi/install/install_bake.sh" \
            | sed -e "s/__BAKE_VERSION__/$VERSION/" -e 's/^BAKE_OFFLINE=0$/BAKE_OFFLINE=1/'
        echo "__PAYLOAD__"
        base64 < "$TARBALL_PATH"
    } > "$PKG/bake"
    chmod +x "$PKG/bake"

    # Every registry Station that passes this release's own `bake safe` scan.
    # shellcheck source=../registry.sh
    source "$(dirname "${BASH_SOURCE[0]}")/../registry.sh"
    PKG_REGISTRY="$TEMP_DIR/registry"
    if git clone --depth 1 --quiet "$REGISTRY_URL" "$PKG_REGISTRY" 2>/dev/null; then
        PASSED=()
        LEFT_OUT=()
        for dir in "$PKG_REGISTRY"/stations/*/; do
            name=$(basename "$dir")
            [ "$name" = "_empty_station" ] && continue
            if HOME="$PKG_HOME" MAKERY_REGISTRY="$PKG_REGISTRY" \
                bash "$TEMP_DIR/multi/makery/headchef/orders/safe.sh" "$name" "" > /dev/null 2>&1; then
                PASSED+=("$name")
            else
                LEFT_OUT+=("$name")
            fi
        done
        H_SAY "✓ In the package: ${PASSED[*]:-none}"
        [ ${#LEFT_OUT[@]} -gt 0 ] && H_SAY "  Left out (failed the scan): ${LEFT_OUT[*]}"
    else
        H_SAY "! Couldn't clone the registry ($MAKERY_REGISTRY), the package has no Stations."
    fi

    # Zip it under a visible name: a folder starting with a dot hides after
    # unzipping. The asset keeps one fixed name, so releases/latest/download/
    # makery-bakery-offline.zip always points at the newest one.
    mv "$PKG" "$PKG_HOME/makery-bakery"
    (cd "$PKG_HOME" && zip -qr "$TEMP_DIR/makery-bakery-offline.zip" makery-bakery)
    cp "$TEMP_DIR/makery-bakery-offline.zip" "$OFFLINE_ZIP"
    OFFLINE_ASSET=("$TEMP_DIR/makery-bakery-offline.zip")
    H_SAY "✓ Saved: $OFFLINE_ZIP ($(du -h "$OFFLINE_ZIP" | cut -f1))"
else
    H_SAY "! zip not found, so this release has no offline package."
fi

# ============================================================================
# PUBLISH GITHUB RELEASE
# ============================================================================
# No CI workflow publishes this anymore (release.yml was removed) — this
# script is now the only thing that turns a pushed tag into a Release with
# the assets bake's self-upgrade downloads (tarball, checksum, installer).
H_SAY "Publishing GitHub release $VERSION..."
gh release create "$VERSION" \
    -R "$MULTI_REPO" \
    --title "$VERSION" \
    --generate-notes \
    "$TARBALL_PATH" \
    "$CHECKSUM_PATH" \
    "$TEMP_DIR/multi/install/install_bake.sh" \
    "${OFFLINE_ASSET[@]}" \
    || { H_SAY "Failed to publish release $VERSION"; exit 1; }
H_SAY "✓ Release published: https://github.com/$MULTI_REPO/releases/tag/$VERSION"

H_FINISHED
