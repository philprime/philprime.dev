# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "tempfile"

module Jekyll
  module Mermaid
    BLOCK_PATTERN = /((`{3,})\s*mermaid!((?:.|\n)*?)\2)/

    CACHE_DIR = File.join(Dir.pwd, ".mermaid-cache")
    OUTPUT_DIR = File.join("assets", "images", "mermaid")

    def self.render_svg(code, site)
      hash = Digest::SHA256.hexdigest(code)[0, 12]
      svg_filename = "#{hash}.svg"
      cache_path = File.join(CACHE_DIR, svg_filename)
      source_path = File.join(site.source, OUTPUT_DIR, svg_filename)

      unless File.exist?(cache_path)
        mmdc = File.join(Dir.pwd, "node_modules", ".bin", "mmdc")
        unless File.exist?(mmdc)
          Jekyll.logger.error "Mermaid:", "mmdc not found at #{mmdc}. Run 'pnpm install' first."
          return nil
        end

        Jekyll.logger.info "Mermaid:", "Rendering #{svg_filename}..."

        Tempfile.create(["mermaid", ".mmd"]) do |input|
          input.write(code)
          input.flush

          Tempfile.create(["mermaid", ".svg"]) do |output|
            cmd = [mmdc, "-i", input.path, "-o", output.path, "-b", "transparent", "-q"]
            _stdout, stderr, status = Open3.capture3(*cmd)

            unless status.success?
              Jekyll.logger.error "Mermaid:", "mmdc failed for #{svg_filename}: #{stderr}"
              return nil
            end

            FileUtils.mkdir_p(CACHE_DIR)
            FileUtils.cp(output.path, cache_path)
            Jekyll.logger.info "Mermaid:", "Cached #{svg_filename}"
          end
        end
      end

      # Copy from cache to source only if missing or changed,
      # to avoid triggering Jekyll's file watcher in serve mode
      unless File.exist?(source_path) && FileUtils.identical?(cache_path, source_path)
        FileUtils.mkdir_p(File.dirname(source_path))
        FileUtils.cp(cache_path, source_path)
      end

      # Register as a static file so Jekyll copies it to _site
      unless site.static_files.any? { |f| f.path == source_path }
        site.static_files << Jekyll::StaticFile.new(
          site, site.source, OUTPUT_DIR, svg_filename
        )
        Jekyll.logger.info "Mermaid:", "Registered static file #{svg_filename}"
      end

      File.join("/", OUTPUT_DIR, svg_filename)
    end

    def self.process(content, site)
      content.gsub(BLOCK_PATTERN) do
        code = Regexp.last_match(3)
        svg_path = render_svg(code.strip, site)

        if svg_path
          "<img class=\"mermaid\" src=\"#{svg_path}\" alt=\"Mermaid diagram\">"
        else
          Regexp.last_match(0)
        end
      end
    end
  end
end

Jekyll::Hooks.register [:pages, :documents], :pre_render do |item|
  next unless item.extname == ".md"
  next unless item.content&.include?("mermaid!")

  Jekyll.logger.info "Mermaid:", "Processing #{item.relative_path}"
  item.content = Jekyll::Mermaid.process(item.content, item.site)
end
