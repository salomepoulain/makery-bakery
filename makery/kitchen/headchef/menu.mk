# ============================================================================
#  THE HEAD CHEF'S MENU
# ============================================================================

menu::
	@bash -c 'source .makery/kitchen/headchef/personality.sh && H_STARTER "The Head Chef'\''s Menu" && \
		ITEM "inspo" 		"List all available stations at the agency" && \
		ITEM "first <name>" "Bake first time <name> by hiring <name> specialised cook" && \
		ITEM "burnt <name>" "Fire a cook by letting the cook bake a burnt product" && \
		ITEM "fresh <name>" "Force the cook to scrub their specific workbench using dishsoap" && \
		ITEM "germs" 		"Force all cooks to use their dishsoap" && \
		ITEM "all" 			"Bake everything at once, closes the makery" && \
		ITEM "station"		"Create a new station to modify according to your wishes" && \
		ITEM "request" 		"Send pull request with your station updates to the registry" && \
		H_LINE'

inspo::
	@bash .makery/kitchen/headchef/orders/inspo.sh

first::
	@bash .makery/kitchen/headchef/orders/first.sh $(s)

burnt::
	@bash .makery/kitchen/headchef/orders/burnt.sh $(s)

germs::
	@bash .makery/kitchen/headchef/orders/fresh.sh

fresh::
	@bash .makery/kitchen/headchef/orders/fresh.sh $(s)

all::
	@bash .makery/kitchen/headchef/orders/all.sh

call::
	@bash -c 'S="$(s)"; D="$(d)"; \
		source .makery/kitchen/headchef/personality.sh && \
		H_STARTER "BAKING $${S^^}'\''s $${D^^}"; \
		if (cd .makery/kitchen/stations/$(s) && make -f menu.mk -n $(d) >/dev/null 2>&1); then \
			(cd .makery/kitchen/stations/$(s) && make -f menu.mk $(d)); \
		else \
			H_SAY "Not on the menu: $(d)"; \
		fi; \
		H_FINISHED'

# Build station menus dynamically (append after headchef menu)
menu::
	@for station_dir in .makery/kitchen/stations/*/; do \
		[ "$$(basename "$$station_dir")" = "_empty_station" ] && continue; \
		[ -d "$$station_dir" ] && [ -f "$$station_dir/menu.mk" ] && $(MAKE) -f "$$station_dir/menu.mk" menu || true; \
	done


help:: menu

# adding a comment t test something here
request::
	@bash .makery/kitchen/headchef/orders/request.sh

in::
	@bash .makery/kitchen/headchef/orders/in.sh

release::
	@bash .makery/kitchen/headchef/orders/release.sh

station::
	@bash .makery/kitchen/headchef/orders/station.sh $(s)
