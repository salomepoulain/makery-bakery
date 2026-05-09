<img src="makery-bakery.png" width="400" alt="makery-bakery">

> A modular recipe-book system for your project's development environment.

`makery-bakery` is a declarative scaffolding system powered by Make. Instead of copying Makefiles between projects, you hire specialized **Stations** to set up environments and run tasks. Think of it as a package manager for boilerplate with personality.

---

## The Bakery Metaphor

- `.makery` is a tiny bakery that lives in your repository.
- The **Head Chef** (`.makery/kitchen/headchef`) is the main orchestrator.
- **Stations** are workspaces where specialized **Recipes** get baked — each Station focuses on one kind of action and brings its own dependencies.
- **Contraband** (`.makery/kitchen/headchef/pockets/.contraband`) lists global files and paths to keep out of version control. Each Station can also declare its own contraband for Station-specific exclusions.
- You **order Recipes** from the menu with `bake`.

When you order a new Dish (`first <name>`):
- The Head Chef hires the appropriate Station.
- The Station checks its dependencies and sets itself up.
- At hire time the Station runs its start contract (for example, creating a `.venv` for Python) so common setup happens automatically.

Cleaning and refreshing:
- If a Station caches files, wash it with `bake fresh <name>`.
- `bake germs` cleans all workbenches (kitchen-wide).
- `bake burnt <name>` fires the Station and runs its stop script to undo leftovers.

Hidden workspace:
- `.makery` is hidden from git by default.

---

## Getting Started

There are two installation paths: one for `bake` users and one for `make` users.

### Path A: Using `bake` (recommended)

1. **Install the `bake` command globally — once:**
   ```bash
   curl -sSL https://github.com/salomepoulain/makery-bakery/releases/latest/download/install_bake.sh | bash
   ```
   This downloads the latest release and writes a single self-contained binary to `~/.local/bin/bake`. The makery payload is embedded in the binary itself — no global `~/.makery/` directory, no other state. The installer is published as a release asset (versioned alongside the tarball it installs), so you can pin a specific tag for reproducible installs.

2. **In any project folder, just run `bake`:**
   ```bash
   bake
   ```
   On first use, `bake` extracts the embedded payload into `./.makery/` automatically. Subsequent runs skip extraction and route straight to make. Your project's `Makefile` stays untouched.

**Upgrading:** re-run the same `curl|bash` command. It overwrites `~/.local/bin/bake` with a fresh payload from the latest release. Existing projects keep their old `.makery/`; new projects get the new payload.

When you bootstrap a new project, `bake` also checks GitHub for a newer release and offers to use it (and optionally upgrade your global binary). Set `BAKE_NO_UPDATE_CHECK=1` to disable the check.

### Path B: Using `make` directly

If you prefer to use `make` directly without installing `bake`:

```bash
# 1. Clone makery-bakery temporarily
git clone --depth 1 https://github.com/salomepoulain/makery-bakery.git .makery-temp

# 2. Set up the kitchen (creates Makefile with makery hooks)
bash .makery-temp/install/install_make.sh

# 3. Clean up
rm -rf .makery-temp
```

Run this in each project where you want makery installed.

Now use `make` directly:
```bash
make first s=python       # Hire the python station
make call s=python d=test  # Run a dish from a station
make fresh s=python       # Clean the python workbench
make germs                # Clean all workbenches
make burnt s=python       # Fire the python station
```

**Note:** This modifies your project's `Makefile` to include makery targets.

---

## Core Commands (customer-facing)

- `bake` — Show the menu (bootstraps `.makery/` on first use in a project).
- `bake inspo` — List available Stations/dishes from the registry..
- `bake first <name>` — Hire a Station and run its onboarding.
- `bake fresh <name>` — Force a Station to scrub its workspace.
- `bake burnt <name>` — Fire a Station and undo its leftovers.
- `bake germs` — Kitchen-wide cleanup of all workbenches.
- `bake all` — Fire all Stations and remove `.makery`.
- `bake station <name>` — Scaffold a new Station from the `_empty_station` template.
- `bake request` — Send a PR with your local station updates to the registry.

**Note:** The bake command routes commands automatically — core operations take a station name (e.g., `bake first python`), while station dishes use the `call` target (e.g., `bake python test` → `make call s=python d=test`).

---

## Bake vs. Make

There are two ways to use makery-bakery:

### Option A: `bake` (recommended for most users)

`bake` uses an internal `.makery/menu.mk` and leaves your project's `Makefile` completely untouched. Your `Makefile` can be committed to version control without any makery modifications.

- `bake first python` → `make -f .makery/menu.mk first s=python` (core commands)
- `bake python test` → `make -f .makery/menu.mk call s=python d=test` (station dishes)

### Option B: `make` directly (for Makefile integration)

If you want to use `make` directly or integrate makery targets into your project's build system, manually add these lines to your `Makefile`:

```makefile
.PHONY: menu first burnt germs fresh all call

-include .makery/kitchen/headchef/menu.mk
-include .makery/kitchen/stations/*/menu.mk
```

Then use:
- `make first s=python` (core commands)
- `make call s=python d=test` (station dishes)

This is useful if you want makery tasks alongside your existing Makefile targets, but requires your `Makefile` to be modified.

---

## Available Recipes (station structure)

A Station is a regular Makefile with explicit targets and comments. It works standalone — just `cd` to the station directory and run `make <recipe>`.

```
station-name/
├── menu.mk                  # Makefile with menu:: and recipe targets
├── cook/
│   ├── personality.sh       # Cook identity (icon, name, color)
│   ├── contract/
│   │   ├── .prerequisite    # Required system tools (e.g., python, node)
│   │   ├── hired.sh         # Runs once when the Station is hired
│   │   └── fired.sh         # Runs once when the Station is fired
│   └── recipes/
│       └── example.sh       # Example recipe (bake call s=<name> d=example)
└── workbench/
    ├── .contraband          # Station-specific entries appended to .gitignore
    └── .dishsoap            # Paths/caches deleted by `bake fresh`
```

Published reference: `salomepoulain/makery-stations`.

---

## Creating New Stations

Stations live in a registry (default: `salomepoulain/makery-stations`). Use the template in `.makery/kitchen/stations/_empty_station/` to create new Stations. Run `bake station <name>` to scaffold a new one automatically.

### Writing a Station `menu.mk`

Write a regular Makefile with a `menu::` double-colon target and your recipe targets. The lifecycle scripts (`hired.sh`, `fired.sh`) are run directly by the Head Chef — they don't belong as Make targets in `menu.mk`.

```makefile
# station-name/menu.mk
# Standalone Makefile — works with: cd .makery/kitchen/stations/<name> && make <recipe>

# Recipes defined below are run via: bake call s=<station> d=<recipe>
# (first, fresh, burnt are managed by the Head Chef)

# Compute station directory when included from main menu.mk
STATION_DIR := $(dir $(lastword $(MAKEFILE_LIST)))

menu::
	@bash -c 'source "$(STATION_DIR)cook/personality.sh" && STARTER "$$COOK_NAME'\''s Menu" && \
		ITEM "<<example>>" "<<Description of the recipe>>" && \
		LINE'

# Add your recipes below:

example:
	@bash $(STATION_DIR)cook/recipes/example.sh
```

The `menu::` double-colon rule appends to the Head Chef's `menu::` — so `bake menu` shows your station's section after the core operations. Replace the placeholder values with your actual station name and recipe descriptions.

The headchef provides a `call` target that routes to stations. Use `make call s=<station> d=<recipe>` or let `bake` handle routing automatically.

### Station structure requirements

Each Station provides:
- `menu.mk` (copy from `.makery/kitchen/stations/_empty_station/menu.mk`, update the station name, and add recipe targets),
- `cook/contract/hired.sh` and `cook/contract/fired.sh` for setup and teardown,
- `cook/contract/.prerequisite` listing required system tools,
- `cook/recipes/` for recipe scripts,
- `cook/personality.sh` with the station's icon, name, and color,
- a `workbench/` with `.contraband` and `.dishsoap`.

---

## Security and Reproducibility

- The `install_bake.sh` script downloads a release tarball and verifies its SHA256 before embedding it. The tarball contents are then frozen inside your `bake` binary.
- Inspect `install/install_bake.sh` and the resulting `~/.local/bin/bake` before running if you want to audit what the installer does.
- For reproducible installs, pin a specific release tag rather than letting the installer fetch `latest`.

---

## Installation — Verified Releases

Each release publishes:
- `makery-bakery-<tag>.tar.gz` — the makery payload (contents of the `makery/` folder, unprefixed)
- `makery-bakery-<tag>.tar.gz.sha256` — SHA256 checksum
- `install_bake.sh` — self-contained installer with the payload embedded at build time

The installer downloads the tarball + checksum and verifies the checksum before embedding the tarball into your `bake` binary. Manual verification:

```bash
TAG=v0.1.0
curl -sSL -O https://github.com/salomepoulain/makery-bakery/releases/download/$TAG/makery-bakery-$TAG.tar.gz
curl -sSL -O https://github.com/salomepoulain/makery-bakery/releases/download/$TAG/makery-bakery-$TAG.tar.gz.sha256
sha256sum -c makery-bakery-$TAG.tar.gz.sha256
```

For reproducible installs, pin a specific tag (`/releases/download/<tag>/install_bake.sh`) rather than `latest`.

---

## Contributing

To add a Station:
1. Follow the Station template.
2. Publish to the registry (e.g., `salomepoulain/makery-stations`).
3. Update the changelog and create a signed Git tag for the release.

---

## Development Setup

### Pre-commit hooks

We use the [pre-commit](https://pre-commit.com/) framework to lint shell scripts before commit:

```bash
# One-time setup
pip install pre-commit
pre-commit install

# Install shellcheck (if not already installed)
# macOS: brew install shellcheck
# Ubuntu: sudo apt install shellcheck
```

The `.pre-commit-config.yaml` runs `shellcheck` on all `*.sh` files staged for commit.

### CI Safety Net

The GitHub Actions workflow (`.github/workflows/test.yml`) also runs shellcheck on every push to `main` and on PRs — this catches anything that slipped past the pre-commit hook.
