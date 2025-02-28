.PHONY: build serve install optimize optimize-images

install:
	bundle install

build: install
	bundle exec jekyll build

serve: install
	bundle exec jekyll serve

optimize: optimize-images

optimize-images:
	find _site -type f -name "*.jpg" -o -name "*.png" -o -name "*.gif" | xargs -I {} jpegoptim --strip-all {}
