.PHONY: build serve install

install:
	bundle install

build: install
	bundle exec jekyll build

serve: install
	bundle exec jekyll serve
