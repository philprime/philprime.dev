source "https://rubygems.org"

gem "jekyll"

gem "minima", github: "jekyll/minima", ref: "5ce4006d175e6e5278bb63a0aad1a85e3bf2370b"

# If you want to use GitHub Pages, remove the "gem "jekyll"" above and
# uncomment the line below. To upgrade, run `bundle update github-pages`.
# gem "github-pages", group: :jekyll_plugins

# If you have any plugins, put them here!
group :jekyll_plugins do
  gem "jekyll-feed", "~> 0.12"
  gem "jekyll-seo-tag", "~> 2.1"
end

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

# GitHub Gist Embedding
gem "jekyll-gist"

# Analytics
gem 'jekyll-analytics'
