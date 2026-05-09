#!/bin/bash
# ============================================================================
#  HEAD CHEF: ALL (Bake everything, overload the ovens)
# ============================================================================

# shellcheck source=../personality.sh
source "$(dirname "${BASH_SOURCE[0]}")/../personality.sh"

H_STARTER "BAKING ALL, EVERYONE IS COOKED... (Total Kitchen Destruction)"


KITCHEN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo -ne "  ${HC_COLOR}$HC_ICON${NC} Are you absolutely sure? The ovens will explode. (y/N) "
read -n 1 -r
echo 
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    H_SAY "You turned off the ovens. The kitchen is safe."
    exit 0
fi

# Run fired.sh on all cooks to ensure system changes are reverted first
H_SAY "Baking all chefs..."
for dir in "$KITCHEN_ROOT/stations"/*/; do
    if [ ! -d "$dir" ]; then continue; fi
    if [ "$(basename "$dir")" = "_empty_station" ]; then continue; fi
    STATION_NAME=$(basename "$dir")
    if [ -f "$dir/cook/contract/fired.sh" ]; then
        H_SAY "Teardown protocol at the '$STATION_NAME' station (running fired.sh)..."
        bash "$dir/cook/contract/fired.sh"
    fi
done

H_SAY "Going full pyro mode, burning down the kitchen..."

rm -rf "$KITCHEN_ROOT/stations"

rm -f bake
rm -f Makefile.thin

# Clean up .makery hooks from Makefile (if open_make was used)
CURRENT_DIR="$(dirname "$KITCHEN_ROOT")"
if [ -f "$CURRENT_DIR/Makefile" ]; then
    if grep -q "# --- MAKERY HOOKS ---" "$CURRENT_DIR/Makefile"; then
        H_SAY "Removing makery hooks from Makefile..."
        # Remove the makery hooks section and everything after it
        sed -i.bak '/^# --- MAKERY HOOKS ---$/,$ d' "$CURRENT_DIR/Makefile"
        rm -f "$CURRENT_DIR/Makefile.bak"
    fi
fi

H_SAY "Saying my final goodbye.."
MAKERY_PATH="$(dirname "$KITCHEN_ROOT")"
rm -rf "$MAKERY_PATH"

H_FINISHED
