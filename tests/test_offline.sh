#!/bin/bash
# Test the offline registry: `bake safe` on a machine with internet, and an
# offline bake that hires only from ~/.makery-bakery. Builds a real bake binary
# from install_bake.sh, with a fake registry and a throwaway HOME. No network.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; echo "$OUT"; exit 1; }

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
export HOME="$TEMP_DIR/home"
mkdir -p "$HOME"
echo "Testing the offline registry in $TEMP_DIR"

# --- A fake online registry: one clean station, one that downloads ---
REG="$TEMP_DIR/registry"
mkdir -p "$REG/stations/good/cook/contract" "$REG/stations/bad/cook/skills" "$REG/stations/bad/cook/contract"
cat > "$REG/stations/good/cook/contract/hired.sh" << 'EOF'
#!/bin/bash
# curl https://example.com would be bad, but this is only a comment
touch hired-good.txt   # see https://example.com
EOF
printf 'menu::\n\t@true\n' > "$REG/stations/good/menu.mk"
printf '#!/bin/bash\ntrue\n' > "$REG/stations/bad/cook/contract/hired.sh"
printf '#!/bin/bash\ncurl -sL https://example.com -o x\n' > "$REG/stations/bad/cook/skills/fetch.sh"
printf 'menu::\n\t@true\n' > "$REG/stations/bad/menu.mk"

# --- Build a bake binary the way install_bake.sh does ---
BAKE="$TEMP_DIR/bin/bake"
mkdir -p "$TEMP_DIR/bin"
{
    awk "/^  cat << '__BAKE_HEAD_EOF__'\$/{flag=1;next} /^__BAKE_HEAD_EOF__\$/{flag=0} flag" \
        "$PROJECT_ROOT/install/install_bake.sh" | sed 's/__BAKE_VERSION__/test/'
    echo "__PAYLOAD__"
    tar -czf - -C "$PROJECT_ROOT/makery" . | base64
} > "$BAKE"
chmod +x "$BAKE"
grep -q '^BAKE_OFFLINE=0$' "$BAKE" || fail "built bake has no BAKE_OFFLINE=0 line"
pass "built an online bake from install_bake.sh"

OFFLINE_BAKE="$HOME/.makery-bakery/bake"
run() { OUT=$("$@" 2>&1) && STATUS=0 || STATUS=$?; }

# --- On the laptop: bake safe ---
mkdir -p "$TEMP_DIR/laptop" && cd "$TEMP_DIR/laptop"
export MAKERY_REGISTRY="$REG"

run "$BAKE" safe good
[ "$STATUS" -eq 0 ] || fail "bake safe good should pass"
[ -f "$HOME/.makery-bakery/stations/good/cook/contract/hired.sh" ] || fail "good was not copied to the offline registry"
pass "bake safe copies a clean station (comments with curl/URLs don't count)"

[ ! -e "$OFFLINE_BAKE" ] || fail "bake safe should no longer write an offline bake itself"
pass "bake safe only fills the registry, it doesn't write a bake"

# --- The offline bake, built by install/build_offline_bake.sh ---
tar -czf "$TEMP_DIR/makery.tar.gz" -C "$PROJECT_ROOT/makery" .
run bash "$PROJECT_ROOT/install/build_offline_bake.sh" "$TEMP_DIR/makery.tar.gz" test "$OFFLINE_BAKE"
[ "$STATUS" -eq 0 ] || fail "build_offline_bake.sh failed"
grep -q '^BAKE_OFFLINE=1$' "$OFFLINE_BAKE" || fail "offline bake does not have BAKE_OFFLINE=1"
OFFLINE_HEAD=$(awk '/^__PAYLOAD__$/{exit} 1' "$OFFLINE_BAKE")
if echo "$OFFLINE_HEAD" | grep -qE 'curl|wget|https?://|_bake_update|_bake_check_upgrade|_bake_download_latest'; then
    fail "the offline head still has update or download code"
fi
OFFLINE_KITCHEN="$TEMP_DIR/offline-kitchen"
mkdir -p "$OFFLINE_KITCHEN"
awk '/^__PAYLOAD__$/{flag=1; next} flag' "$OFFLINE_BAKE" | base64 -d | tar -xzf - -C "$OFFLINE_KITCHEN"
for order in in request release safe; do
    [ ! -e "$OFFLINE_KITCHEN/headchef/orders/$order.sh" ] || fail "the offline kitchen still has $order.sh"
done
if grep -qE 'ITEM "(request|in|update|safe)[" ]|^(request|in|release|safe)::' "$OFFLINE_KITCHEN/headchef/menu.mk"; then
    fail "the offline menu still offers GitHub commands"
fi
if grep -rhE 'git (clone|pull|push|fetch)|curl|wget|github\.com' "$OFFLINE_KITCHEN/headchef" | grep -vE '^[[:space:]]*#'; then
    fail "the offline kitchen still has network code"
fi
pass "the offline bake has no update code, no GitHub orders and no git clone"

# A kitchen with network code left in it must not become an offline bake.
LEAKY="$TEMP_DIR/leaky"
mkdir -p "$LEAKY"
cp -R "$PROJECT_ROOT/makery/." "$LEAKY/"
printf '#!/bin/bash\ncurl -sL https://example.com\n' > "$LEAKY/headchef/orders/leak.sh"
tar -czf "$TEMP_DIR/leaky.tar.gz" -C "$LEAKY" .
run bash "$PROJECT_ROOT/install/build_offline_bake.sh" "$TEMP_DIR/leaky.tar.gz" test "$TEMP_DIR/leaky-bake"
[ "$STATUS" -ne 0 ] || fail "build_offline_bake.sh built a bake with curl in it"
echo "$OUT" | grep -q "leak.sh" || fail "the build refusal does not name the file"
[ ! -e "$TEMP_DIR/leaky-bake" ] || fail "a refused build still wrote its output"
pass "the build refuses a kitchen that still reaches the network"

run "$BAKE" safe bad
[ "$STATUS" -ne 0 ] || fail "bake safe bad should be refused"
[ ! -d "$HOME/.makery-bakery/stations/bad" ] || fail "bad was copied despite the refusal"
echo "$OUT" | grep -q "cook/skills/fetch.sh:2:" || fail "refusal does not name the file and line"
pass "bake safe refuses a station that downloads, and shows file and line"

run "$BAKE" safe bad --force
[ "$STATUS" -eq 0 ] || fail "bake safe bad --force should pass"
[ -d "$HOME/.makery-bakery/stations/bad" ] || fail "bad was not copied with --force"
pass "bake safe --force adds it anyway"

run "$BAKE" safe
echo "$OUT" | grep -q "✓ good" || fail "bake safe without a name did not recheck good"
echo "$OUT" | grep -q "stays as it was" || fail "recheck should keep the old copy of bad"
[ -d "$HOME/.makery-bakery/stations/bad" ] || fail "recheck removed the forced copy of bad"
pass "bake safe without a name rechecks all and keeps old copies it refuses"

# --- On the cluster: the offline bake ---
mkdir -p "$TEMP_DIR/cluster" && cd "$TEMP_DIR/cluster"
export MAKERY_REGISTRY="https://example.invalid/should-be-ignored"

run "$OFFLINE_BAKE" update
[ "$STATUS" -ne 0 ] || fail "offline bake update should refuse"
echo "$OUT" | grep -q "offline bake" || fail "offline update refusal has no clear message"
pass "offline bake refuses update"

# Before any station is hired, so an unknown order can't fall through to one.
for order in in request release safe; do
    run "$OFFLINE_BAKE" "$order"
    [ "$STATUS" -ne 0 ] || fail "offline bake $order should not run"
    echo "$OUT" | grep -q "Not a valid argument" || fail "offline bake $order is not unknown"
done
pass "offline bake doesn't know in, request, release or safe"

run "$OFFLINE_BAKE" first good
[ "$STATUS" -eq 0 ] || fail "offline bake first good should hire from the offline registry"
[ -f hired-good.txt ] || fail "good's hired.sh did not run"
pass "offline bake hires from ~/.makery-bakery and ignores MAKERY_REGISTRY"

run "$OFFLINE_BAKE" inspo
echo "$OUT" | grep -q "good" || fail "offline inspo does not list the offline registry"
pass "offline bake inspo lists the offline registry"

# --- The offline package that `bake release` builds ---
# Run release.sh's OFFLINE PACKAGE block on its own, against the fake registry,
# then use the zip the way a machine with only a browser would.
PKG_TEST="$TEMP_DIR/release"
mkdir -p "$PKG_TEST/multi" "$PKG_TEST/archives"
cp -R "$PROJECT_ROOT/makery" "$PROJECT_ROOT/install" "$PKG_TEST/multi/"
tar -czf "$PKG_TEST/makery.tar.gz" -C "$PROJECT_ROOT/makery" .
BLOCK="$PKG_TEST/multi/makery/headchef/orders/package_block.sh"
{
    # shellcheck disable=SC2016 # written out literally, expanded when the block runs
    echo 'source "$(dirname "${BASH_SOURCE[0]}")/../personality.sh"'
    awk '/^# OFFLINE PACKAGE/{flag=1} /^# PUBLISH GITHUB RELEASE/{flag=0} flag' \
        "$PROJECT_ROOT/makery/headchef/orders/release.sh" | sed '$d'
    # shellcheck disable=SC2016
    echo 'echo "ASSET=${OFFLINE_ASSET[0]}"'
} > "$BLOCK"
(cd "$REG" && git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm stations)
run env -u MAKERY_OFFLINE MAKERY_REGISTRY="$REG" TEMP_DIR="$PKG_TEST" ARCHIVE_DIR="$PKG_TEST/archives" \
    VERSION=vtest TARBALL_PATH="$PKG_TEST/makery.tar.gz" bash "$BLOCK"
[ "$STATUS" -eq 0 ] || fail "the offline package block failed"
ZIP="$PKG_TEST/makery-bakery-offline.zip"
[ -f "$ZIP" ] || fail "no makery-bakery-offline.zip was built"
echo "$OUT" | grep -q "ASSET=$ZIP" || fail "the zip is not passed on as a release asset"
LIST=$(unzip -Z1 "$ZIP")
echo "$LIST" | grep -qx "makery-bakery/bake" || fail "the zip has no makery-bakery/bake"
echo "$LIST" | grep -q "^makery-bakery/stations/good/" || fail "the zip is missing the good station"
if echo "$LIST" | grep -q "^makery-bakery/stations/bad/"; then fail "the zip contains the bad station"; fi
pass "bake release builds makery-bakery-offline.zip with only the stations that pass the scan"

# Like on the cluster: a fresh home, unzip, rename, chmod, hire.
export HOME="$TEMP_DIR/cluster-home"
mkdir -p "$HOME" && cd "$HOME"
unzip -q "$ZIP" && mv makery-bakery .makery-bakery && chmod +x .makery-bakery/bake
grep -q '^BAKE_OFFLINE=1$' .makery-bakery/bake || fail "the packaged bake is not offline"
grep -q '^BAKE_VERSION="vtest"$' .makery-bakery/bake || fail "the packaged bake has no version"
if awk '/^__PAYLOAD__$/{exit} 1' .makery-bakery/bake | grep -qE 'curl|_bake_update'; then
    fail "the packaged bake still has update code"
fi
mkdir -p "$TEMP_DIR/cluster2" && cd "$TEMP_DIR/cluster2"
run "$HOME/.makery-bakery/bake" first good
{ [ "$STATUS" -eq 0 ] && [ -f hired-good.txt ]; } || fail "the packaged offline bake could not hire good"
pass "the unzipped package hires on a machine without internet"

echo ""
echo "All offline registry tests passed!"
