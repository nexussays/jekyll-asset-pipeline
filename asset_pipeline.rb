module Jekyll

  ASSET_CACHE_DIR = ".asset_cache"

  class AssetPipeline < Generator
    require 'pathname'

    safe true
    
    attr_accessor :project_source, :project_dest
    # _config.yml value
    attr_accessor :asset_source, :asset_dest, :fail_on_error

    def generate(site)
      # I hate having the output being on the same line as Jekyll's "Generating..."
      puts

      @site = site
      config = @site.config

      # Don't assume defaults. Require source and destination to be set in _config.yml
      if config['asset_pipeline'] == nil || config['asset_pipeline']['source'] == nil ||
         config['asset_pipeline']['destination'] == nil
        raise "\nAsset pipeline requires source and destination defined in _config.yml, eg:\n" +
          "asset_pipeline:\n" +
          "  source:       ./_assets\n" +
          "  destination:  .\n"
      end

      self.asset_source = config['asset_pipeline']['source']
      self.asset_dest = config['asset_pipeline']['destination']
      self.fail_on_error = config['asset_pipeline']['fail_on_error']

      self.project_source = File.expand_path(config['source'])
      self.project_dest = File.expand_path(config['destination'])

      @cache_root = File.join(self.project_source, self.asset_source, ASSET_CACHE_DIR)
      #TODO: check if files in cache are newer than the source files and don't regenerate everything
      FileUtils.rm_rf(@cache_root)

      puts "Processing asset pipeline..."

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
          @assets << Asset.new(@site, File.join(self.project_source, self.asset_source), dir.gsub(self.asset_source, ""), f)
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
              puts "#{converter} failed on file '#{asset.original_name}'"
              if self.fail_on_error
                raise e
              else
                puts e
              end
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

        # change each asset to point to the cached file on disk and add it to the sites static_files array
        #puts "#{asset.base} | #{asset.dir} | #{asset.name}"
        asset.dir = File.join(ASSET_CACHE_DIR, asset.dir)
        #puts asset.path
        #@site.static_files << asset

      end
      puts "Assets processed."
    end

  end

  class Asset < Jekyll::StaticFile

    attr_reader :original_name, :base
    attr_accessor :dir, :name, :ext, :content

    def initialize(site, base, dir, name)
      super(site, base, dir, name)
      @original_name = name
      self.ext = File.extname(name)
      self.content = File.read(File.join(base, dir, name))
    end
  end

end