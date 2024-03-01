# NewText — icon & app build
# Thin wrapper over scripts/build.sh. Run `make help` for details.

BUILD := ./scripts/build.sh

.PHONY: all icons icns icon car apps clean cache-reset help

all: ## Rebuild everything: icns -> icon -> car -> apps
	@$(BUILD) all

icons: ## Rebuild icons only (icns + icon + car)
	@$(BUILD) icons

icns: ## Generate legacy .icns from master_1024.png
	@$(BUILD) icns

icon: ## Assemble Icon Composer .icon bundles from SVG + json
	@$(BUILD) icon

car: ## Compile Assets.car from the .icon bundles (actool)
	@$(BUILD) car

apps: ## Duplicate the template app and install icons
	@$(BUILD) apps

clean: ## Remove the build/ directory
	@$(BUILD) clean

cache-reset: ## Restart Dock & Finder to flush the icon cache
	@$(BUILD) cache-reset

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'
