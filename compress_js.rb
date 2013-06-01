module Jekyll

  class JsCompressor < Converter
    require 'closure-compiler'
    safe true
    priority :low

    def initialize(config)

    end

    def matches(ext)
      #puts "JsCompressor: #{ext}" if ext == ".js"
      ext == ".js"
    end

    def output_ext(ext)
      ".js"
    end

    def convert(content)
      return Closure::Compiler.new.compile(content)
    end
  end

end