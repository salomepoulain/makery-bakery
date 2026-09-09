# ============================================================================
#  THE HEAD CHEF'S MENU
# ============================================================================

menu::
	@bash -c 'source .makery/headchef/personality.sh && H_STARTER "The Head Chef'\''s Menu" && \
		ITEM "inspo" 		"List all available stations at the agency" && \
		ITEM "first <name>" "Bake first time <name> by hiring <name> specialised cook" && \
		ITEM "last/burnt <name>" "Fire a cook by letting the cook bake a burnt product" && \
		ITEM "clean/germs [name]" 		"Force all cooks (or just [name]) to use their dishsoap" && \
		ITEM "station"		"Create a new station to modify according to your wishes" && \
		ITEM "shady [path]"	"No path: stash this project'\''s contraband into .shadow/. With a path: stash just that too" && \
		ITEM "request" 		"Send pull request with your station updates to the registry" && \
		ITEM "all" 			"Bake the whole kitchen (project) at once, except the stash, closing the makery" && \
		H_LINE'

inspo::
	@bash .makery/headchef/orders/inspo.sh

first::
	@bash .makery/headchef/orders/first.sh $(s)

burnt::
	@bash .makery/headchef/orders/burnt.sh $(s)

last::
	@bash .makery/headchef/orders/last.sh $(s)

germs::
	@bash .makery/headchef/orders/fresh.sh $(s)

clean::
	@bash .makery/headchef/orders/clean.sh $(s)

all::
	@bash .makery/headchef/orders/all.sh

call::
	@bash -c 'S="$(s)"; D="$(d)"; \
		source .makery/headchef/personality.sh && \
		H_STARTER "BAKING $${S^^}'\''s $${D^^}"; \
		if (cd .makery/stations/$(s) && make -f menu.mk -n $(d) >/dev/null 2>&1); then \
			(cd .makery/stations/$(s) && make -f menu.mk $(d)); \
		else \
			H_SAY "Not on the menu: $(d)"; \
		fi; \
		H_FINISHED'

# Build station menus dynamically (append after headchef menu)
menu::
	@for station_dir in .makery/stations/*/; do \
		[ "$$(basename "$$station_dir")" = "_empty_station" ] && continue; \
		[ -d "$$station_dir" ] && [ -f "$$station_dir/menu.mk" ] && $(MAKE) -f "$$station_dir/menu.mk" menu || true; \
	done


help:: menu

request::
	@bash .makery/headchef/orders/request.sh

in::
	@bash .makery/headchef/orders/in.sh

release::
	@bash .makery/headchef/orders/release.sh

station::
	@bash .makery/headchef/orders/station.sh $(s)

shady::
	@bash .makery/headchef/orders/shady.sh $(s)
