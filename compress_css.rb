module Jekyll
  class CssCompressor < Converter
    gem 'sass', '~> 3.2'
    require 'sass'
    safe true
    priority :low

    def initialize(config)

    end

    def matches(ext)
      #puts "CssCompressor: #{ext}" if ext == ".css"
      ext == ".css"
    end

    def output_ext(ext)
      ".css"
    end

    def convert(content)
      return Sass::Engine.new(content, :syntax => :scss, :style => :compressed).render
    end
  end
end