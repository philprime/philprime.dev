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
      output_path = File.join(site.source, OUTPUT_DIR, svg_filename)

      # Use cached SVG if it exists
      if File.exist?(cache_path)
        FileUtils.mkdir_p(File.dirname(output_path))
        FileUtils.cp(cache_path, output_path) unless File.exist?(output_path)
        return File.join("/", OUTPUT_DIR, svg_filename)
      end

      # Render with mmdc
      mmdc = File.join(Dir.pwd, "node_modules", ".bin", "mmdc")
      # Also check pnpm location
      unless File.exist?(mmdc)
        mmdc = `pnpm bin`.strip + "/mmdc"
      end
      unless File.exist?(mmdc)
        Jekyll.logger.error "Mermaid:", "mmdc not found. Run 'npm install' first."
        return nil
      end

      Tempfile.create(["mermaid", ".mmd"]) do |input|
        input.write(code)
        input.flush

        Tempfile.create(["mermaid", ".svg"]) do |output|
          cmd = [mmdc, "-i", input.path, "-o", output.path, "-b", "transparent", "-q"]
          stdout, stderr, status = Open3.capture3(*cmd)

          unless status.success?
            Jekyll.logger.error "Mermaid:", "mmdc failed: #{stderr}"
            return nil
          end

          svg_content = File.read(output.path)

          # Cache and copy to output
          FileUtils.mkdir_p(CACHE_DIR)
          FileUtils.mkdir_p(File.dirname(output_path))
          File.write(cache_path, svg_content)
          File.write(output_path, svg_content)

          return File.join("/", OUTPUT_DIR, svg_filename)
        end
      end
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

  item.content = Jekyll::Mermaid.process(item.content, item.site)
end
