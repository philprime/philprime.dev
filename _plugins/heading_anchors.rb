module Jekyll
  module HeadingAnchors
    HEADING_PATTERN = /<h([1-6])([^>]*)\sid=(['"])([^'"]+)\3([^>]*)>(.*?)<\/h\1>/mi

    def self.inject(html)
      html.gsub(HEADING_PATTERN) do |match|
        level = Regexp.last_match(1)
        before_id_attrs = Regexp.last_match(2)
        quote = Regexp.last_match(3)
        heading_id = Regexp.last_match(4)
        after_id_attrs = Regexp.last_match(5)
        heading_body = Regexp.last_match(6)

        next match if heading_body.include?("class=\"autolink-heading\"")
        next match if heading_body.include?("class='autolink-heading'")

        anchor = "<a class=\"autolink-heading\" href=\"##{heading_id}\" aria-hidden=\"true\" tabindex=\"-1\">"
        icon = "<span class=\"anchorlink\" aria-hidden=\"true\">#</span>"

        "<h#{level}#{before_id_attrs} id=#{quote}#{heading_id}#{quote}#{after_id_attrs}>#{anchor}#{heading_body}#{icon}</a></h#{level}>"
      end
    end
  end
end

Jekyll::Hooks.register [:pages, :posts, :documents], :post_render do |item|
  next unless item.output_ext == ".html"
  next unless item.output

  item.output = Jekyll::HeadingAnchors.inject(item.output)
end
