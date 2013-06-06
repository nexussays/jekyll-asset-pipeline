module Jekyll
  class SassConverter < Converter
    gem 'sass', '~> 3.2'
    require 'sass'
    safe true
    priority :normal

    def initialize(config)
      @settings = { syntax: :scss }
      # Check for presence of assets dir in config.
      # Don't assume we're running from within asset-pipeline
      if config["assets"] != nil
        # Add all subdirectories to load path.
        # The likelihood of same-named files in different directories is outweighed by the convenience of
        # not having to track down and understand obscure @import errors from SASS
        @settings[:load_paths] = Dir[File.join(config["assets"], "**/")]
      end
      #p @settings
    end

    def matches(ext)
      #puts "SassConverter: #{ext}" if ext =~ /^\.s[ac]ss$/i
      ext =~ /^\.s[ac]ss$/i
    end

    def output_ext(ext)
      ".css"
    end

    def convert(content)
      return Sass::Engine.new(content, @settings).render
    end
  end
end