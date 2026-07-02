CE_DIR       := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
CRAWLER_ROOT := $(shell git -C "$(CE_DIR)" rev-parse --show-toplevel)

GODOT_BIN ?= $(shell which godot 2>/dev/null)

.PHONY: up down mcp schema verify

## Start the editor (http://localhost:5173)
up:
	@lsof -ti :5173 :5174 | xargs kill -9 2>/dev/null; true
	cd "$(CRAWLER_ROOT)" && PROJECT_ROOT="$(CRAWLER_ROOT)" npm run dev --prefix tools/content_editor

## Run the stdio MCP server in the foreground (for manual testing via an MCP inspector)
mcp:
	cd "$(CRAWLER_ROOT)" && PROJECT_ROOT="$(CRAWLER_ROOT)" \
	  npm run mcp --workspace=sidecar --prefix tools/content_editor

## Stop all editor processes
down:
	@lsof -ti :5173 :5174 | xargs kill -9 2>/dev/null; true

## Re-export schema.json from Godot (run after changing GDScript class definitions)
schema:
	@[ -n "$(GODOT_BIN)" ] || { echo "ERROR: godot not found. Set GODOT_BIN=/path/to/godot"; exit 1; }
	cd "$(CRAWLER_ROOT)" && GODOT_EXECUTABLE="$(GODOT_BIN)" PROJECT_ROOT="$(CRAWLER_ROOT)" \
	  npm run schema --prefix tools/content_editor

## Round-trip parse+serialise every .tres in resources/ — zero structural diffs required
verify:
	cd "$(CRAWLER_ROOT)" && PROJECT_ROOT="$(CRAWLER_ROOT)" \
	  npm run verify-tres --workspace=sidecar --prefix tools/content_editor
