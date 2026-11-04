#!/bin/bash
# ============================================================================
#  BUILD OFFLINE BAKE
# ============================================================================
# Builds a bake binary for a machine without internet, from a release tarball
# (the makery/ folder) and the bake head in install_bake.sh. The result holds
# no network code at all, not even switched off:
#   - the orders that need GitHub (in, request, release, safe) are deleted,
#     with their menu items;
#   - every block between "# >>> online-only" and "# <<< online-only" is cut
#     out of the head and the kitchen (update checks, downloads, git clone);
#   - then the whole result is scanned with bake safe's own pattern, and the
#     build fails if anything that reaches the network is left.
#
# Usage: build_offline_bake.sh <makery-tarball.tar.gz> <version> <output-file>

set -euo pipefail

TARBALL="$1"
VERSION="$2"
OUT="$3"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
KITCHEN="$WORK/kitchen"
mkdir -p "$KITCHEN"
tar -xzf "$TARBALL" -C "$KITCHEN"

# The scan pattern lives in safe.sh, which is about to go: read it first.
DANGER=$(sed -n "s/^DANGER='\(.*\)'$/\1/p" "$KITCHEN/headchef/orders/safe.sh")
[ -n "$DANGER" ] || { echo "build_offline_bake: no DANGER pattern found in safe.sh" >&2; exit 1; }

# Cut every online-only block out of a file, keeping its permissions.
strip_online() {
    awk '/# >>> online-only/{skip=1; next} /# <<< online-only/{skip=0; next} !skip' "$1" > "$WORK/stripped"
    cat "$WORK/stripped" > "$1"
}

# --- 1. The kitchen ---
rm -f "$KITCHEN"/headchef/orders/{in,request,release,safe}.sh
awk '
    /ITEM "(request|in|update|safe)[" ]/ { next }
    /^(request|in|release|safe)::/      { skip = 1; next }
    skip && /^\t/                        { next }
                                         { skip = 0; print }
' "$KITCHEN/headchef/menu.mk" > "$WORK/menu.mk"
cat "$WORK/menu.mk" > "$KITCHEN/headchef/menu.mk"
grep -rl '# >>> online-only' "$KITCHEN" | while IFS= read -r file; do
    strip_online "$file"
done

# --- 2. The head ---
awk "/^  cat << '__BAKE_HEAD_EOF__'\$/{flag=1; next} /^__BAKE_HEAD_EOF__\$/{flag=0} flag" \
    "$HERE/install_bake.sh" > "$WORK/head"
strip_online "$WORK/head"
sed -i.bak -e "s/__BAKE_VERSION__/$VERSION/" -e 's/^BAKE_OFFLINE=0$/BAKE_OFFLINE=1/' "$WORK/head"
grep -q '^BAKE_OFFLINE=1$' "$WORK/head" || { echo "build_offline_bake: couldn't switch the head to offline" >&2; exit 1; }

# --- 3. Nothing that reaches the network may be left ---
# Same rules as bake safe: scripts only, comments don't count.
is_script() {
    case "$1" in
        *.sh | *.bash | *.zsh | *.py | *.mk | */Makefile | *.pl | *.rb | *.js | *.ts) return 0 ;;
    esac
    head -c 2 "$1" 2>/dev/null | grep -q '^#!'
}
hits=""
while IFS= read -r file; do
    { [ "$file" = "$WORK/head" ] || is_script "$file"; } || continue
    found=$(grep -nI '' "$file" 2>/dev/null \
        | sed -E 's#^([0-9]+:)[[:space:]]*(\#|//).*$#\1#; s#[[:space:]]\#.*$##; s#^([0-9]+:)#\1 #' \
        | sed -E 's#https?://(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])([:/][^[:space:]"'"'"']*)?([^[:alnum:]._-]|$)#\3#g' \
        | grep -E "^[0-9]+:.*($DANGER)" || true)
    [ -n "$found" ] || continue
    while IFS= read -r line; do
        hits+="  ${file#"$WORK"/}:$line"$'\n'
    done <<< "$found"
done < <(echo "$WORK/head"; find "$KITCHEN" -type f | sort)
if grep -rqE '# (>>>|<<<) online-only' "$WORK/head" "$KITCHEN"; then
    hits+="  an online-only marker was left behind (unbalanced >>> / <<<)"$'\n'
fi
if [ -n "$hits" ]; then
    echo "build_offline_bake: the offline bake would still reach the network:" >&2
    printf '%s' "$hits" >&2
    exit 1
fi

# --- 4. Head + payload ---
{
    cat "$WORK/head"
    echo "__PAYLOAD__"
    COPYFILE_DISABLE=1 tar -czf - -C "$KITCHEN" . | base64
} > "$OUT"
chmod +x "$OUT"
