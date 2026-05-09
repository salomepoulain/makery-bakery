# station-name/menu.mk
# Standalone Makefile — works with: cd .makery/kitchen/stations/<name> && make <recipe>

# Recipes defined below are run via: bake call s=<station> d=<recipe>
# (first, fresh, burnt are managed by the Head Chef)

# Compute station directory when included from main menu.mk
STATION_DIR := $(dir $(lastword $(MAKEFILE_LIST)))

menu::
	@bash -c 'source "$(STATION_DIR)cook/personality.sh" && STARTER "$$COOK_NAME'"'"'s Menu" && \
		ITEM "<<example>>" "<<Description of the recipe>>" && \
		LINE'

# Add your recipes below:

# models: Switch between Anthropic and OpenRouter providers
example:
	@bash $(STATION_DIR)cook/recipes/example.sh
