# Makefile for Questie-X development tasks
# Requires: lua5.1, busted, selene

BUSTED   := busted
SELENE   := selene

.PHONY: test test-verbose lint ci clean

# Run all Busted unit tests
test:
	$(BUSTED)

# Run tests with verbose output
test-verbose:
	$(BUSTED) --verbose

# Run selene linter with WoW Classic ruleset
lint:
	$(SELENE) --config selene.toml .

# CI: run lint + test
ci: lint test

# Clean up temporary/generated files
clean:
	rm -f luac.out *.bak
