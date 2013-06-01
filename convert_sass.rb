module Jekyll
  class SassConverter < Converter
    require 'sass'
    safe true
    priority :normal

    def matches(ext)
      #puts "SassConverter: #{ext}" if ext =~ /^\.s[ac]ss$/i
      ext =~ /^\.s[ac]ss$/i
    end

    def output_ext
      ".css"
    end

    def convert(content)
      # output as expanded CSS. Separate compress_css.rb Converter will compress the CSS if not in dev/test mode
      return Sass::Engine.new(content, syntax: :scss, :style => :expanded).render
    end
  end
end