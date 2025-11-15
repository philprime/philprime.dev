## Setup Ruby
#
# This target ensures that the correct Ruby version is being used
# for the project by utilizing `rbenv` to set the local Ruby version
.PHONY: setup-ruby
setup-ruby:
	rbenv install -s

## Install project dependencies
#
# This target installs all required Ruby gems specified in the
# `Gemfile` using Bundler.
.PHONY: install
install: setup-ruby
	bundle install

## Build the Jekyll site
#
# This target compiles the Jekyll site into static files, which are
# output to the `_site` directory.
.PHONY: build
build: install
	bundle exec jekyll build

## Serve the Jekyll site locally with live reloading
#
# This target starts a local development server for the Jekyll site,
# allowing you to preview changes in real-time as you edit the source files.
# After starting you can access the site at http://localhost:4000
.PHONY: serve
serve: install
	bundle exec jekyll serve

## Optimize assets
#
# This target runs all optimization tasks for the project.
.PHONY: optimize
optimize: optimize-images

## Optimize all images in the `assets/images` directory
#
# This target runs a script that optimizes images to reduce file size
# without compromising quality. It processes common image formats such as
# JPEG, PNG, and GIF found in the `assets/images` directory.
.PHONY: optimize-images
optimize-images:
	./bin/optimize-image.bash

# ============================================================================
# HELP & DOCUMENTATION
# ============================================================================

## Show this help message with all available commands
#
# Displays a formatted list of all available make targets with descriptions.
# Commands are organized by topic for easy navigation.
.PHONY: help
help:
	@echo "=============================================="
	@echo "🚀 SHIPABLE DEPLOYER DEVELOPMENT COMMANDS"
	@echo "=============================================="
	@echo ""
	@awk 'BEGIN { desc = ""; target = "" } \
	/^## / { desc = substr($$0, 4) } \
	/^\.PHONY: / && desc != "" { \
		target = $$2; \
		printf "\033[36m%-20s\033[0m %s\n", target, desc; \
		desc = ""; target = "" \
	}' $(MAKEFILE_LIST)
	@echo ""
	@echo "💡 Use 'make <command>' to run any command above."
	@echo "📖 For detailed information, see comments in the Makefile."
	@echo ""
