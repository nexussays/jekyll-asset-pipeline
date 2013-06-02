module Jekyll
  class SassConverter < Converter
    gem 'sass', '~> 3.2'
    require 'sass'
    safe true
    priority :normal

    def initialize(config)

    end

    def matches(ext)
      #puts "SassConverter: #{ext}" if ext =~ /^\.s[ac]ss$/i
      ext =~ /^\.s[ac]ss$/i
    end

    def output_ext
      ".css"
    end

    def convert(content)
      # output as ":style => :expanded" because compression is separate (compress_css.rb)
      return Sass::Engine.new(content, syntax: :scss, :style => :expanded).render
    end
  end
end