#!/bin/bash
# ============================================================================
#  INSTALL MAKE (Per-project kitchen setup for make users)
# ============================================================================
# This script initializes a kitchen for projects using `make` directly.
# Run from a fresh clone of the repo (Path B in README).
# A Makefile with makery includes will be created in your project.
# ============================================================================

# --- Formatting Helpers ---
_term_cols() { local cols; cols=$(stty size 2>/dev/null | awk '{print $2}'); [[ "$cols" =~ ^[0-9]+$ ]] && echo "$cols" || echo 80; }
WHITE='\033[1;37m'
NC='\033[0m'

STARTER() { local rule cols; cols=$(_term_cols); rule=$(awk -v n="$cols" 'BEGIN{while(i++<n)printf"━";print""}'); rule_thin=$(awk -v n="$cols" 'BEGIN{while(i++<n)printf"┈";print""}'); echo -e "${WHITE}${rule}${NC}"; echo -e "${WHITE}  $1${NC}"; echo -e "${WHITE}${rule_thin}${NC}"; }
FINISHED() { local rule cols; cols=$(_term_cols); rule=$(awk -v n="$cols" 'BEGIN{while(i++<n)printf"━";print""}'); rule_thin=$(awk -v n="$cols" 'BEGIN{while(i++<n)printf"┈";print""}'); echo -e "\n${WHITE}${rule_thin}${NC}"; echo -e "${WHITE}  $1${NC}"; echo -e "${WHITE}${rule}${NC}"; }

# Locate the makery payload in the repo (this script lives at <repo>/install/)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SRC="$REPO_ROOT/makery"

if [ ! -d "$SRC/kitchen" ] || [ ! -f "$SRC/menu.mk" ]; then
    echo -e "\033[1;31mError: $SRC is missing or incomplete. Run from a fresh clone of makery-bakery.\033[0m" >&2
    exit 1
fi

STARTER "LAYING THE FOUNDATION (Make Setup)..."

# 1. Mirror the makery payload into this project's .makery/
mkdir -p .makery
cp -r "$SRC/kitchen" .makery/
cp "$SRC/menu.mk" .makery/menu.mk

# 2. Create a Makefile with makery includes
if [ ! -f "Makefile" ]; then
    echo "  Creating Makefile with makery hooks..."
    cat << 'EOF' > Makefile
.PHONY: menu first burnt germs fresh all call

-include .makery/kitchen/headchef/menu.mk
-include .makery/kitchen/stations/*/menu.mk

# Default goal: show the menu
.DEFAULT_GOAL := menu
EOF
else
    # Hook into existing Makefile if necessary
    if ! grep -q "\.makery/kitchen/headchef/menu\.mk" Makefile; then
        echo "  Adding Makery hooks to existing Makefile..."
        {
            echo -e "\n# --- MAKERY HOOKS ---"
            echo "-include .makery/kitchen/headchef/menu.mk"
            echo "-include .makery/kitchen/stations/*/menu.mk"
        } >> Makefile
    fi
fi

# 3. Set permissions for the Head Chef's orders
chmod +x .makery/kitchen/headchef/orders/*.sh

# 4. Hide the kitchen from Git
if [ -f ".gitignore" ]; then
    if ! grep -q "^\.makery/$" .gitignore; then
        echo -e "\n# --- MAKERY ---" >> .gitignore
        echo ".makery/" >> .gitignore
    fi
else
    echo ".makery/" > .gitignore
fi

# 5. Safety check: Ensure no local 'bake' file clutters the workspace
rm -f bake 2>/dev/null

FINISHED "✓ Local kitchen is open and ready."