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
# TAG & PUSH (workflow .github/workflows/release.yml will create the release)
# ============================================================================
H_SAY "Tagging main with $VERSION..."
git tag "$VERSION" 2>/dev/null || { H_SAY "Failed to create tag $VERSION"; exit 1; }

H_SAY "Pushing tag (CI will publish the release)..."
git push origin "$VERSION" --quiet 2>/dev/null || { H_SAY "Failed to push tag"; exit 1; }
H_SAY "✓ Tag pushed: https://github.com/$MULTI_REPO/releases/tag/$VERSION"

# ============================================================================
# DOWNLOAD TARBALL LOCALLY & GENERATE CHECKSUM
# ============================================================================
cd "$REPO_ROOT" || exit 1
TARBALL_URL="https://github.com/$MULTI_REPO/archive/refs/tags/$VERSION.tar.gz"
TARBALL_PATH="$ARCHIVE_DIR/makery-bakery-$VERSION.tar.gz"
CHECKSUM_PATH="$ARCHIVE_DIR/makery-bakery-$VERSION.tar.gz.sha256"

H_SAY "Downloading tarball..."
curl -sL "$TARBALL_URL" -o "$TARBALL_PATH" || { H_SAY "Failed to download tarball"; exit 1; }

TARBALL_SIZE=$(du -h "$TARBALL_PATH" | cut -f1)
H_SAY "✓ Saved: $TARBALL_PATH ($TARBALL_SIZE)"

# Generate local checksum (release assets are produced by CI)
H_SAY "Generating checksum..."
sha256sum "$TARBALL_PATH" | awk '{print $1}' > "$CHECKSUM_PATH"
H_SAY "✓ Checksum: $(cat "$CHECKSUM_PATH")"

H_FINISHED
