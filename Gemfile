source "https://rubygems.org"

gem "jekyll"

# Windows and JRuby does not include zoneinfo files, so bundle the tzinfo-data gem
# and associated library.
platforms :mingw, :x64_mingw, :mswin, :jruby do
  gem "tzinfo", "~> 2.0"
  gem "tzinfo-data"
end

# Performance-booster for watching directories on Windows
gem "wdm", "~> 0.2.0", :platforms => [:mingw, :x64_mingw, :mswin]

# Lock `http_parser.rb` gem to `v0.6.x` on JRuby builds since newer versions of the gem
# do not have a Java counterpart.
gem "http_parser.rb", "~> 0.6.0", :platforms => [:jruby]

# Missing dependency used by the jekyll base binary
gem "webrick"

# Code Highlighting
gem "kramdown-parser-gfm"
gem "kramdown"
gem "rouge"

# Feeds
gem "jekyll-feed", "~> 0.12"

# SEO
gem "jekyll-seo-tag", "~> 2.1"

# GitHub Gist Embedding
gem "jekyll-gist"

# Analytics
gem 'jekyll-analytics'
