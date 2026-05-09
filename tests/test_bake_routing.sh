#!/bin/bash
# Test bake routing logic

set -e

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

echo "Testing bake routing logic..."

# Test the routing logic (extracted from install_makery.sh bake scripting)
test_bake_args() {
    local args=("$@")
    local num_args=$#
    local second="${args[1]:-}"

    # This mirrors the logic in the bake script
    if [ $num_args -ge 2 ] && [[ ! "$second" == *=* ]]; then
        echo "try_first_then_call"
    else
        echo "pass_through"
    fi
}

# Test routing cases
result=$(test_bake_args "first" "python")
if [ "$result" = "try_first_then_call" ]; then
    pass "first python -> try_first_then_call"
else
    fail "first python routing"
fi

result=$(test_bake_args "python" "deploy")
if [ "$result" = "try_first_then_call" ]; then
    pass "python deploy -> try_first_then_call"
else
    fail "python deploy routing"
fi

result=$(test_bake_args "first" "s=python")
if [ "$result" = "pass_through" ]; then
    pass "first s=python -> pass_through"
else
    fail "first s=python routing"
fi

result=$(test_bake_args "germs")
if [ "$result" = "pass_through" ]; then
    pass "germs -> pass_through"
else
    fail "germs routing"
fi

result=$(test_bake_args "menu")
if [ "$result" = "pass_through" ]; then
    pass "menu -> pass_through"
else
    fail "menu routing"
fi

result=$(test_bake_args "first" "python" "extra")
if [ "$result" = "try_first_then_call" ]; then
    pass "first python extra -> try_first_then_call"
else
    fail "first python extra routing"
fi

echo ""
echo "All bake routing tests passed!"