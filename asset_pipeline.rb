module Jekyll

  class AssetPipeline < Generator
    require 'yaml'
    require 'digest/sha1'

    safe true
    
    attr_accessor :project_source, :project_dest, :asset_source

    def initialize(config)
      @bundle = true
      @includes_dir = "_includes"
      @error_include_file = "asset_pipeline_errors"
      @error_log_file = "asset_pipeline_errors.log"
      @asset_cache_dir = ".asset_cache"
      @bundle_dir = ".bundles"
    end

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

      @cache_root = File.join(self.project_source, self.asset_source, @asset_cache_dir)

      # load map file which contains the SHA1 hash of every file the last time it was processed
      @map_file = File.join(@cache_root, "cache.yaml")
      @map = Hash.new
      begin
        @map = YAML.load_file(@map_file) if File.exists?(@map_file)
      rescue Exception
        #noop
      end
      @map = Hash.new if @map == nil || !(@map.is_a? Hash)

      puts "          Assets..."

      @assets = []
      self.read_files(self.asset_source)
      self.process
      self.write_cache
      self.bundle if @bundle
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
          asset = Asset.new(@site,
              File.join(self.project_source, self.asset_source),
              dir.gsub(self.asset_source, ""), f)
          @assets << asset
          
          # See if the file is cached or if we should re-generate it
          
          # appending "sha1" because the YAML serializer seems to detect that 
          # the string is in hex and writes it out in base-64
          hash = "sha1:" + Digest::SHA1.hexdigest(asset.content).to_s
          #puts "#{hash} | #{@map[path]}"
          # skip processing this asset if the asset hasn't changed and the processed file exists
          if @map.has_key?(asset.orig_path) &&
             @map[asset.orig_path].is_a?(Hash) &&
             @map[asset.orig_path].has_key?('hash') &&
             @map[asset.orig_path]['hash'] == hash &&
             @map[asset.orig_path].has_key?('out') &&
             File.exists?(File.join(@cache_root, @map[asset.orig_path]['out']))
            #puts "#{asset.name} is cached"
            asset.in_cache = true
          else
            # if the hash doesn't exist, add it
            @map[asset.orig_path] = {'hash' => hash}
          end
        end
      end
    end

    # Convert assets based on the file extension if converter is defined
    def process
      errors = []
      bad_assets = []
      @assets.each do |asset|
        # Convert asset multiple times if more than one converter is found
        finished = false
        # Create a duplicate of the converters for the site so we can mutate the array
        converters = @site.converters.dup
        while !finished
          # get the highest priority converter
          converter = converters.find { |c| c.matches(asset.ext) }
          if converter != nil
            begin
              # run converter if the asset is not cached
              asset.content = converter.convert(asset.content) unless asset.in_cache
              # store current extension in case we need to restore it
              last_ext = asset.ext
              # get the extension from the converter
              converter_ext = converter.output_ext(asset.ext)
              # now remove current extension
              asset.name = File.basename(asset.name, asset.ext)
              #puts "#{asset.original_name}: #{converter.class.name}: #{last_ext} | #{converter_ext} | #{asset.ext}"
              # if the converter extension is not the same as the next in the chain, add the converter extension back
              if asset.ext != converter_ext
                asset.name = asset.name + converter_ext
              end
            rescue Exception => e
              error = "#{converter.class.name} failed on file '#{asset.original_name}'\n#{e}"
              # Don't raise the exception again. Output the info and carry on with the
              # rest of the assets, but don't copy this one to the output directory.
              puts error
              # Add this error message to the errors array so we can write out all errors to a file
              errors << error
              # Flag this asset as having errors, it will be removed below
              bad_assets << asset
              # And stop processing this asset since there was a failure in the pipeline
              finished = true
            ensure
              # remove converter from the list so we don't run twice or end up in an infinite loop
              converters.delete(converter)
            end
          else
            finished = true
            #puts asset.name
          end
        end
      end
      # remove assets that errored out during procesing
      @assets.delete_if {|a| bad_assets.include?(a) }

      # store the final asset path in the cache map
      @assets.each do |asset|
        @map[asset.orig_path]['out'] = File.join(asset.dir, asset.name)
      end

      # write errors to the asset_pipeline_errors.log include so users can see errors on
      # page refresh instead of having to view the console window
      error_log = File.join(self.project_source, @includes_dir, @error_log_file)
      # don't create if the include file doesn't exist
      if File.exists?(File.join(self.project_source, @includes_dir, @error_include_file))
        output = if errors.length > 0 then
          "<span id=\"asset_pipeline_errors\" " +
            "style=\"background-color: red;color: white;font-weight: bold;"+
            "font-family:'Inconsolata','Consolas','Andale Mono',monospace;"+
            "font-size: 12px;white-space: pre;width: 100%;display: block;\">" + 
          # simpleton HTML scaping
          errors.join("\n\n").gsub("&", "&amp;").gsub("<", "&lt;") +
          "</span>"
        else
          ""
        end
        current = File.exists?(error_log) ? File.read(error_log).chomp : nil
        # only write file if there are changes, if the directory watcher is running it'll infinitely cycle
        if output != current
          File.open(error_log, 'w') do |f|
            f.write(output)
          end
        end
      end
      puts "  Assets processed."
    end

    def write_cache
      # write out each procssed asset file to the cache
      @assets.each do |asset|
        cache =  asset.destination(@cache_root)
        # If the asset is in the cache already, load the cached data in case we bundle
        if asset.in_cache
          asset.content = File.read(cache)
        # otherwise persist changes to disk in cache directory
        else
          FileUtils.mkdir_p(File.dirname(cache))
          File.open(cache, 'w') do |f|
            f.write(asset.content)
          end
        end
      end

      # dump the file mapping
      File.open(@map_file, 'w') do |file|
        file.write(YAML::dump(@map))
      end
    end

    # TODO: Clean up this method
    def bundle
      collections = Hash.new
      # aggregate all assets of the same type that share the same prefix
      @assets.each do |asset|
        #puts "#{asset.name} <= #{asset.original_name}"
        sections = asset.name.split('.')
        collections[sections[0]] = Hash.new if collections[sections[0]] == nil
        hash = collections[sections[0]]
        hash[sections[-1]] = [] if hash[sections[-1]] == nil
        hash[sections[-1]] << asset
      end

      # combine files
      collections.each do |k1, v1|
        v1.each do |k, v|
          if v.length > 1
            pack = nil
            in_cache = true
            v.sort {|x,y| x.original_name <=> y.original_name }
            #puts "#{k1}: #{v.length}"
            v.each do |bundle_asset|
              in_cache &&= bundle_asset.in_cache
              # Initialize the bundle file with the first file in the bundle
              if pack == nil
                pack = bundle_asset
                pack.name = "#{k1}.#{k}"
                pack.is_bundle = true
                #puts "Bundling. #{pack.name} <= #{bundle_asset.original_name}"
                next
              end
              #puts "Bundling. #{pack.name} <= #{bundle_asset.original_name}"
              pack.content << bundle_asset.content
              @assets.delete bundle_asset
            end

            # If a single part of the bundle is not in cache, write out the new bundle
            if !in_cache
              #puts "Bundled #{k1}.#{k}"
              cache =  pack.destination(File.join(@cache_root, @bundle_dir))
              FileUtils.mkdir_p(File.dirname(cache))
              File.open(cache, 'w') do |f|
                f.write(pack.content)
              end
            end
          end
        end
      end

      puts "    Assets bundled."
    end

    def write
      # copy each final asset or asset bundle to jekyll's static_files so they are copied to the destination
      @assets.each do |asset|
        # Add the asset cache directory to the base path so the files will be picked up on disk
        if asset.is_bundle
          asset.base = File.join(asset.base, File.join(@asset_cache_dir, @bundle_dir))
        else
          asset.base = File.join(asset.base, @asset_cache_dir)
        end
        
        # add it to the sites static_files array
        @site.static_files << asset
      end
      #puts "      Assets saved."
    end

  end

  class Asset < Jekyll::StaticFile

    # New attributes
    attr_reader :original_name
    attr_accessor :content, :in_cache, :is_bundle
    # Exposed private fields of Jekyll::StaticFile
    attr_reader :dir
    attr_accessor :name, :base

    def initialize(site, base, dir, name)
      super(site, base, dir, name)
      self.in_cache = false
      self.is_bundle = false
      self.content = File.read(File.join(base, dir, name))
      @original_name = name
      @orig_path = File.join(@dir, @original_name)
    end

    def ext
      File.extname(@name)
    end

    def orig_path
      @orig_path
    end

  end

end