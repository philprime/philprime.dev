module Jekyll
  module Ordinalize
    def ordinalize(number)
      if number.to_i.to_s != number.to_s
        return number
      end

      num = number.to_i

      if (11..13).include?(num % 100)
        "#{num}th"
      else
        case num % 10
        when 1 then "#{num}st"
        when 2 then "#{num}nd"
        when 3 then "#{num}rd"
        else "#{num}th"
        end
      end
    end
  end
end

Liquid::Template.register_filter(Jekyll::Ordinalize)
