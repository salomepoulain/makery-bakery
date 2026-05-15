#!/bin/bash
# ============================================================================
#  INSTALL BAKE (Global installer for the bake command)
# ============================================================================
# Downloads the latest makery release and writes a self-contained `bake`
# binary to ~/.local/bin/bake. The binary embeds the entire makery payload;
# no global headquarters directory is created. Re-run this script to upgrade.
# ============================================================================

# --- Formatting Helpers ---
_term_cols() { local cols; cols=$(stty size 2>/dev/null | awk '{print $2}'); [[ "$cols" =~ ^[0-9]+$ ]] && echo "$cols" || echo 80; }
WHITE='\033[1;37m'
NC='\033[0m'

STARTER() { local rule cols; cols=$(_term_cols); rule=$(awk -v n="$cols" 'BEGIN{while(i++<n)printf"━";print""}'); rule_thin=$(awk -v n="$cols" 'BEGIN{while(i++<n)printf"┈";print""}'); echo -e "${WHITE}${rule}${NC}"; echo -e "${WHITE}  $1${NC}"; echo -e "${WHITE}${rule_thin}${NC}"; }
FINISHED() { local rule cols; cols=$(_term_cols); rule=$(awk -v n="$cols" 'BEGIN{while(i++<n)printf"━";print""}'); rule_thin=$(awk -v n="$cols" 'BEGIN{while(i++<n)printf"┈";print""}'); echo -e "\n${WHITE}${rule_thin}${NC}"; echo -e "${WHITE}  $1${NC}"; echo -e "${WHITE}${rule}${NC}"; }

set -euo pipefail

REPO_URL="https://github.com/salomepoulain/makery-bakery"

# Fetch the latest release tag dynamically (public endpoint, no auth needed)
RELEASE_TAG=$(curl -sSL \
  "https://api.github.com/repos/salomepoulain/makery-bakery/releases/latest" 2>/dev/null | \
  grep '"tag_name"' | sed 's/.*"tag_name": "\([^"]*\)".*/\1/' || true)

if [ -z "$RELEASE_TAG" ]; then
  echo -e "\033[1;33mWarning: Could not fetch latest release from GitHub API (rate limited or offline).\033[0m"
  echo "API endpoint: https://api.github.com/repos/salomepoulain/makery-bakery/releases/latest"
  echo ""
  echo "Attempting to download from recent stable release..."
  # Scrape releases page to find available versions
  RELEASES=$(curl -sSL "$REPO_URL/releases" 2>/dev/null | grep -o 'href="[^"]*releases/tag/v[^"]*"' | sed 's/.*tag\///' | sed 's/".*//' || echo "")

  if [ -z "$RELEASES" ]; then
    echo -e "\033[1;31mFailed to fetch available releases - cannot proceed.\033[0m"
    echo "Please ensure you have internet access and try again."
    exit 1
  fi

  echo "Available releases:"
  echo "$RELEASES" | head -5 | while read -r rel; do
    echo "  • $rel"
  done
  echo ""

  RELEASE_TAG=$(echo "$RELEASES" | head -1)
  echo "Selecting: $RELEASE_TAG (most recent available)"
fi

TARBALL_NAME="makery-bakery-${RELEASE_TAG}.tar.gz"
CHECKSUM_NAME="${TARBALL_NAME}.sha256"
BIN_DIR="$HOME/.local/bin"
BINARY_NAME="bake"

# Warn about PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo -e "\n\033[1;33mNOTE: $HOME/.local/bin is not in your PATH.\033[0m"
  echo "Add it with:"
  echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
  printf "and consider adding that line to your shell profile.\n"
fi

mkdir -p "$BIN_DIR"

# Fetch release tarball and checksum, then verify
TMP_TARBALL=$(mktemp)
TMP_CHECKSUM=$(mktemp)

echo "Downloading $REPO_URL/releases/download/$RELEASE_TAG/$TARBALL_NAME ..."
curl -sSL -o "$TMP_TARBALL" "$REPO_URL/releases/download/$RELEASE_TAG/$TARBALL_NAME"

echo "Downloading checksum..."
curl -sSL -o "$TMP_CHECKSUM" "$REPO_URL/releases/download/$RELEASE_TAG/$CHECKSUM_NAME"

echo "Verifying checksum..."
EXPECTED_HASH=$(awk '{print $1}' "$TMP_CHECKSUM" 2>/dev/null || echo "")
ACTUAL_HASH=$(sha256sum "$TMP_TARBALL" | awk '{print $1}')

if [ -z "$EXPECTED_HASH" ]; then
  echo -e "\033[1;33mWarning: Could not download checksum file. Skipping verification.\033[0m"
  echo "(You can verify manually: sha256sum makery-bakery-$RELEASE_TAG.tar.gz)"
elif [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
  echo -e "\033[1;31mChecksum verification failed!\033[0m"
  echo "Expected: $EXPECTED_HASH"
  echo "Actual:   $ACTUAL_HASH"
  rm "$TMP_TARBALL" "$TMP_CHECKSUM"
  exit 1
else
  echo "Checksum verified."
fi

# Write the bake binary: head (logic) + payload marker + base64-encoded tarball.
# When invoked, bake reads its own file to extract the payload on first use.
BAKE_PATH="$BIN_DIR/$BINARY_NAME"

echo "Writing self-contained $BINARY_NAME to $BAKE_PATH ..."

{
  cat << '__BAKE_HEAD_EOF__'
#!/bin/bash
# Self-contained bake binary. Embeds the makery payload below the __PAYLOAD__
# marker as a base64-encoded gzip tarball. On first run in a project, extracts
# it into ./.makery/. Subsequent runs just route to make.

BAKE_VERSION="__BAKE_VERSION__"

_bake_logo() {
    cat <<'__EOF__'
           ▄▄  ▗▖ ▗▄▖ ▗▖ ▗▖▗▄▄▄▖▗▄▄▖▗▖  ▗▖
   ▗▜▜▜▖   ▐▛▚▞▜▌▐▌ ▐▌▐▌▗▞▘▐▌   ▐▌ ▐▌▝▚▞▘
    𜴆𜴆𜴆    ▐▌  ▐▌▐▛▀▜▌▐▛▚▖ ▐▛▀▀▘▐▛▀▚▖ ▐▌ ▀▀
   ██▀▀█▄  ▐▌  ▐▌▐▌ ▐▌▐▌ ▐▌▐▙▄▄▖▐▌ ▐▌ ▐▌
   ██ ▄█▀       ▄▄           ▄
   ██▀▀█▄ ▄▀▀█▄ ██ ▄█▀ ▄█▀█▄ ████▄██ ██   ▄
 ▄ ██  ▄█ ▄█▀██ ████   ██▄█▀ ██   ██▄██▄▀▀
 ▀██████▀▄▀█▄██▄██ ▀█▄▄▀█▄▄▄▄█▀    ▀██▀
                                 ▄▀▀██
                                  ▀▀▀
__EOF__
}
_BAKE_REPO_API="https://api.github.com/repos/salomepoulain/makery-bakery/releases/latest"
_BAKE_REPO_DL="https://github.com/salomepoulain/makery-bakery/releases/download"
_BAKE_INSTALLER_URL="https://github.com/salomepoulain/makery-bakery/releases/latest/download/install_bake.sh"

_bake_check_upgrade() {
    # On success, sets _LATEST_TAG and returns 0.
    [ -t 0 ] && [ -t 1 ] || return 1
    [ -z "${BAKE_NO_UPDATE_CHECK:-}" ] || return 1
    local _curl_err _http_code
    _curl_err=$(mktemp)
    _http_code=$(curl -sSL --max-time 8 -w "%{http_code}" -o "$_curl_err" "$_BAKE_REPO_API" 2>&1)
    _LATEST_TAG=$(cat "$_curl_err" | grep '"tag_name"' | sed 's/.*"tag_name": "\([^"]*\)".*/\1/')
    rm -f "$_curl_err"
    if [ -z "$_LATEST_TAG" ]; then
        echo "(could not reach GitHub to check for updates)" >&2
        echo "  API: $_BAKE_REPO_API" >&2
        echo "  HTTP status: $_http_code" >&2
        [ -n "${BAKE_DEBUG:-}" ] && echo "  (set BAKE_NO_UPDATE_CHECK=1 to skip checks)" >&2
        echo "  Using embedded payload ($BAKE_VERSION)" >&2
        return 1
    fi
    [ "$_LATEST_TAG" != "$BAKE_VERSION" ] || return 1
    echo "makery-bakery got renovated: $BAKE_VERSION → $_LATEST_TAG"
    read -r -p "Use the newest version for this project? [y/N] " _ans
    [[ "$_ans" =~ ^[Yy] ]] || return 1
    return 0
}

_bake_download_latest() {
    # Echoes path to verified tarball on success.
    local tmp ck expected actual
    tmp=$(mktemp); ck=$(mktemp)
    if ! curl -sSL --max-time 15 -o "$tmp" "$_BAKE_REPO_DL/$_LATEST_TAG/makery-bakery-$_LATEST_TAG.tar.gz" \
        || ! curl -sSL --max-time 15 -o "$ck" "$_BAKE_REPO_DL/$_LATEST_TAG/makery-bakery-$_LATEST_TAG.tar.gz.sha256"; then
        echo "Download failed, falling back to embedded payload." >&2
        rm -f "$tmp" "$ck"; return 1
    fi
    expected=$(awk '{print $1}' "$ck")
    actual=$(sha256sum "$tmp" | awk '{print $1}')
    rm -f "$ck"
    if [ "$expected" != "$actual" ]; then
        echo "Checksum mismatch, falling back to embedded payload." >&2
        rm -f "$tmp"; return 1
    fi
    echo "$tmp"
}

_bake_extract() {
    local src="" tmp="" _upgraded=0
    if _bake_check_upgrade; then
        if tmp=$(_bake_download_latest); then
            src="$tmp"
            _upgraded=1
            read -r -p "Also upgrade your global bake binary? [y/N] " _ans2
            if [[ "$_ans2" =~ ^[Yy] ]]; then
                echo "Upgrading global bake..."
                curl -sSL "$_BAKE_INSTALLER_URL" | bash
            fi
        else
            echo "Download of $_LATEST_TAG failed — using the version embedded in this binary ($BAKE_VERSION)." >&2
        fi
    fi
    mkdir -p .makery
    if [ -n "$src" ]; then
        tar -xzf "$src" -C .makery
        rm -f "$src"
        echo "Installed .makery/ from $_LATEST_TAG."
    else
        awk '/^__PAYLOAD__$/{flag=1;next}flag' "$0" | base64 -d | tar -xzf - -C .makery
        [ "$_upgraded" -eq 0 ] && echo "Installed .makery/ from embedded payload ($BAKE_VERSION)."
    fi
    chmod +x .makery/kitchen/headchef/orders/*.sh 2>/dev/null
    if [ -f .gitignore ]; then
        grep -q '^\.makery/$' .gitignore || printf '\n# --- MAKERY ---\n.makery/\n' >> .gitignore
    else
        echo ".makery/" > .gitignore
    fi
    rm -f bake 2>/dev/null
}

_bake_upgrade_check() {
    # Bare-bake release check. Two independent y/N prompts: project + global.
    [ -t 0 ] && [ -t 1 ] || return 0
    [ -z "${BAKE_NO_UPDATE_CHECK:-}" ] || return 0
    local latest _curl_err _http_code
    _curl_err=$(mktemp)
    _http_code=$(curl -sSL --max-time 8 -w "%{http_code}" -o "$_curl_err" "$_BAKE_REPO_API" 2>&1)
    latest=$(cat "$_curl_err" | grep '"tag_name"' | sed 's/.*"tag_name": "\([^"]*\)".*/\1/')
    rm -f "$_curl_err"
    if [ -z "$latest" ]; then
        [ -n "${BAKE_DEBUG:-}" ] && echo "Warning: could not check for updates (HTTP $_http_code)" >&2
        return 0
    fi
    [ "$latest" != "$BAKE_VERSION" ] || return 0

    echo "makery-bakery got renovated: $BAKE_VERSION → $latest"

    read -r -p "Upgrade this project's .makery/? [y/N] " _ans1
    if [[ "$_ans1" =~ ^[Yy] ]]; then
        _LATEST_TAG="$latest"
        local tmp
        if tmp=$(_bake_download_latest); then
            rm -rf .makery
            mkdir -p .makery
            tar -xzf "$tmp" -C .makery
            rm -f "$tmp"
            chmod +x .makery/kitchen/headchef/orders/*.sh 2>/dev/null
            echo "Project .makery/ upgraded to $latest."
        fi
    fi

    read -r -p "Upgrade global bake binary? [y/N] " _ans2
    if [[ "$_ans2" =~ ^[Yy] ]]; then
        echo "Upgrading global bake..."
        curl -sSL "$_BAKE_INSTALLER_URL" | bash
    fi
}

# Ensure .makery/ exists in the current directory (just-in-time bootstrap).
[ -d ".makery" ] || _bake_extract

# Handle --version / -v flag
if [ $# -eq 1 ] && [[ "$1" =~ ^(--version|-v)$ ]]; then
    echo "bake $BAKE_VERSION"
    exit 0
fi

# Bare `bake` (no args): release check, then logo.
if [ $# -eq 0 ]; then
    _bake_upgrade_check
    _bake_logo
fi

# Route to make. _empty_station is excluded from single-station auto-routing.
if [ $# -ge 2 ] && [[ ! "$2" == *=* ]]; then
    _bake_first="$1"; _bake_second="$2"; shift 2
    make -f .makery/menu.mk "$_bake_first" s="$_bake_second" "$@" 2>/dev/null || \
        make -f .makery/menu.mk "call" s="$_bake_first" d="$_bake_second" "$@"
elif [ $# -eq 1 ] && [[ ! "$1" == *=* ]]; then
    if ! make -f .makery/menu.mk -n "$1" >/dev/null 2>&1; then
        _stations=()
        for _d in .makery/kitchen/stations/*/; do
            [ -d "$_d" ] || continue
            [ "$(basename "$_d")" = "_empty_station" ] && continue
            _stations+=("$_d")
        done
        if [ ${#_stations[@]} -eq 1 ]; then
            _station=$(basename "${_stations[0]}")
            exec make -f .makery/menu.mk call s="$_station" d="$1"
        fi
    fi
    make -f .makery/menu.mk "$@"
else
    make -f .makery/menu.mk "$@"
fi
exit $?
__BAKE_HEAD_EOF__
  echo "__PAYLOAD__"
  base64 < "$TMP_TARBALL"
} > "$BAKE_PATH"

# Substitute the version placeholder with the actual release tag.
# Avoid sed -i here because BSD sed and GNU sed use different argument forms.
TMP_BAKE_PATH=$(mktemp)
sed "s/__BAKE_VERSION__/$RELEASE_TAG/" "$BAKE_PATH" > "$TMP_BAKE_PATH"
mv "$TMP_BAKE_PATH" "$BAKE_PATH"

chmod +x "$BAKE_PATH"
rm "$TMP_TARBALL" "$TMP_CHECKSUM"

echo "Bake installed to $BAKE_PATH"
echo "Ensure $BIN_DIR is in your PATH."
echo "Then just run 'bake' inside any project folder."
