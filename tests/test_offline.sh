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

[ -x "$OFFLINE_BAKE" ] || fail "bake safe did not write ~/.makery-bakery/bake"
grep -q '^BAKE_OFFLINE=1$' "$OFFLINE_BAKE" || fail "offline bake does not have BAKE_OFFLINE=1"
echo "$OUT" | grep -q "rsync -av ~/.makery-bakery/" || fail "bake safe did not print the rsync command"
pass "bake safe writes an offline bake and prints the rsync command"

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

run "$OFFLINE_BAKE" first good
[ "$STATUS" -eq 0 ] || fail "offline bake first good should hire from the offline registry"
[ -f hired-good.txt ] || fail "good's hired.sh did not run"
pass "offline bake hires from ~/.makery-bakery and ignores MAKERY_REGISTRY"

run "$OFFLINE_BAKE" inspo
echo "$OUT" | grep -q "good" || fail "offline inspo does not list the offline registry"
pass "offline bake inspo lists the offline registry"

for order in in request release safe; do
    run "$OFFLINE_BAKE" "$order"
    [ "$STATUS" -ne 0 ] || fail "offline bake $order should refuse"
    echo "$OUT" | grep -q "offline bake" || fail "offline bake $order has no clear message"
done
pass "offline bake refuses in, request, release and safe"

echo ""
echo "All offline registry tests passed!"
