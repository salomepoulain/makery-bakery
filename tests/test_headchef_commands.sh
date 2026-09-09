#!/bin/bash
# Test headchef commands via make

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MAKERY_SRC="$PROJECT_ROOT/makery"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

pass() {
    echo -e "${GREEN}✓${NC} $1"
}

fail() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

# Create temp directory for testing
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Testing headchef commands..."
echo "Using temp directory: $TEMP_DIR"

cd "$TEMP_DIR"

# Set up a minimal makery environment for make tests
mkdir -p .makery/headchef/orders
cp "$MAKERY_SRC/headchef/menu.mk" .makery/headchef/
cp "$MAKERY_SRC/headchef/personality.sh" .makery/headchef/
cp "$MAKERY_SRC/headchef/orders/inspo.sh" .makery/headchef/orders/
cp "$MAKERY_SRC/headchef/orders/fresh.sh" .makery/headchef/orders/
chmod +x .makery/headchef/orders/*.sh

# Create a minimal Makefile for make tests (user's Makefile path)
cat > Makefile << 'EOF'
.PHONY: menu germs

-include .makery/headchef/menu.mk
.DEFAULT_GOAL := menu
EOF

# Also set up .makery/menu.mk for bake tests (internal menu path)
cp "$MAKERY_SRC/headchef/menu.mk" .makery/menu.mk

# Test 1: make menu
if make menu 2>/dev/null | grep -q "Head Chef's Menu"; then
    pass "make menu displays menu"
else
    fail "make menu did not display expected content"
fi

# Test 2: germs command (works with no stations)
if make germs 2>/dev/null; then
    pass "make germs runs without error"
else
    fail "make germs failed"
fi

# Test 3: Verify the headchef menu.mk has the correct targets
if grep -q "^menu::" "$MAKERY_SRC/headchef/menu.mk"; then

# Test 4: Verify .makery/menu.mk works for bake path
if make -f .makery/menu.mk menu 2>/dev/null | grep -q "Head Chef's Menu"; then
    pass "make -f .makery/menu.mk menu works for bake path"
else
    fail "make -f .makery/menu.mk menu did not display expected content"
fi
    pass "menu target defined in headchef/menu.mk"
else
    fail "menu target not found in headchef/menu.mk"
fi

if grep -q "^germs::" "$MAKERY_SRC/headchef/menu.mk"; then
    pass "germs target defined in headchef/menu.mk"
else
    fail "germs target not found in headchef/menu.mk"
fi

if grep -q "^first::" "$MAKERY_SRC/headchef/menu.mk"; then
    pass "first target defined in headchef/menu.mk"
else
    fail "first target not found in headchef/menu.mk"
fi

if grep -q "^burnt::" "$MAKERY_SRC/headchef/menu.mk"; then
    pass "burnt target defined in headchef/menu.mk"
else
    fail "burnt target not found in headchef/menu.mk"
fi

if grep -q "^clean::" "$MAKERY_SRC/headchef/menu.mk"; then
    pass "clean target defined in headchef/menu.mk"
else
    fail "clean target not found in headchef/menu.mk"
fi

if grep -q "^call::" "$MAKERY_SRC/headchef/menu.mk"; then
    pass "call target defined in headchef/menu.mk"
else
    fail "call target not found in headchef/menu.mk"
fi

echo ""
echo "All headchef command tests passed!"