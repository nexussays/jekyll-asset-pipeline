module Jekyll

  ASSET_CACHE_DIR = ".asset_cache"

  class AssetPipeline < Generator
    require 'pathname'

    safe true
    
    attr_accessor :project_source, :project_dest, :asset_source

    def generate(site)
      # I hate having the output being on the same line as Jekyll's "Generating..."
      puts

      @site = site
      config = @site.config

      # Don't assume defaults. Require directories to be set so the error can explain how it works
      raise "\nAsset pipeline requires source directory defined in _config.yml, eg:\nassets: ./_assets\n" if config['assets'] == nil

      self.asset_source = config['assets']
      self.project_source = File.expand_path(config['source'])
      self.project_dest = File.expand_path(config['destination'])

      @cache_root = File.join(self.project_source, self.asset_source, ASSET_CACHE_DIR)
      #TODO: check if files in cache are newer than the source files and don't regenerate everything
      FileUtils.rm_rf(@cache_root)

      puts "          Assets..."

      @assets = []
      self.read_files(self.asset_source)
      self.process
      self.write
    end

    def read_files(dir = '')
      # use same loading technique as Jekyll so we include & exclude the same files
      base = File.join(self.project_source, dir)
      entries = Dir.chdir(base) { @site.filter_entries(Dir.entries('.')) }
      entries.each do |f|
        f_abs = File.join(base, f)
        f_rel = File.join(dir, f)
        if File.directory?(f_abs)
          next if self.project_dest.sub(/\/$/, '') == f_abs
          # manually ensure that we don't recurse into the asset cache dir, just in case
          # filter_entries() changes and doesn't capture it
          next if @cache_root == f_abs
          read_files(f_rel)
        elsif !File.symlink?(f_abs)
          @assets << Asset.new(@site,
              File.join(self.project_source, self.asset_source),
              dir.gsub(self.asset_source, ""), f)
        end
      end
    end

    # Convert assets based on the file extension if converter is defined
    def process
      @assets.each do |asset|
        # Convert asset multiple times if more than one converter is found
        finished = false
        # Create a duplicate of the converters for the site so we can mutate the array
        converters = @site.converters.dup
        # remember each removed extension so we can restore the last one once no converters are found
        last_ext = ""
        while !finished
          # get the highest priority converter
          converter = converters.find { |c| c.matches(asset.ext) }
          if converter != nil
            begin
              # don't run on identity converter
              if converter.is_a? Jekyll::Converters::Identity
                # restore the last extension once we reach the identity converter
                asset.name += last_ext
                asset.ext = last_ext
              else
                # run converter
                asset.content = converter.convert(asset.content)
                # remove extension instead of replacing it with converter.out_ext
                asset.name = File.basename(asset.name, asset.ext)
                # store current extension in case this is the last conversion and we need to restore it
                last_ext = asset.ext
                # set the new extension
                asset.ext = File.extname(asset.name)  
              end
            rescue Exception => e
              # Don't raise the exception higher, output the info and carry on.
              # Inform the user and let them decide if they want to act or not.
              puts "#{converter} failed on file '#{asset.original_name}'"
              puts e
            ensure
              # remove converter from the list so we don't run again or end up in an infinite loop
              converters.delete(converter)
            end
          else
            finished = true
          end
        end
      end
    end

    def write
      # write out each procssed asset file to the cache
      @assets.each do |asset|
        cache =  asset.destination(@cache_root)

        # save assets to cache
        FileUtils.mkdir_p(File.dirname(cache))
        File.open(cache, 'w') do |file|
          #puts "writing '#{asset.content[0...15]}...' to #{cache}"
          file.write(asset.content)
        end

        # Add the asset cache directory to the base path so the files will be picked up on disk
        asset.base = File.join(asset.base, ASSET_CACHE_DIR)
        # add it to the sites static_files array
        @site.static_files << asset

      end
      puts "  Assets processed."
    end

  end

  class Asset < Jekyll::StaticFile

    # In addition to adding our new attributes...
    attr_reader :original_name
    attr_accessor :ext, :content
    # ...expose the private fields of Jekyll::StaticFile
    attr_accessor :dir, :name, :base

    def initialize(site, base, dir, name)
      super(site, base, dir, name)
      @original_name = name
      self.ext = File.extname(name)
      self.content = File.read(File.join(base, dir, name))
    end

  end

end