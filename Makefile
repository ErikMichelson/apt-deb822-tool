PREFIX ?= /usr/local

help:
	@echo "Usage: make [install] [PREFIX=/path/to/install]"

install:
	install -Dm755 src/apt-deb822-tool.bash $(PREFIX)/bin/apt-deb822-tool

test:
	@bats test

.PHONY: help test
