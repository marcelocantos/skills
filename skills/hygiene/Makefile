# Test harness for the hygiene skill.
#
#   make test   — run the unit tests
#
# Both scripts are `uv run --script` files with pyyaml declared inline, so the
# tests borrow the same dependency rather than assuming an ambient install.
# Run from this directory.

UV ?= uv
PYTHON_WITH_DEPS = $(UV) run --quiet --with pyyaml python

.PHONY: test
test:
	$(PYTHON_WITH_DEPS) -m unittest discover --start-directory tests --verbose
