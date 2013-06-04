module Jekyll

  class AssetPipelineErrorLogGenerator < Generator
    safe true
    
    def generate(site)
      error_log = File.expand_path(File.join(site.config["source"],"_includes","asset_pipeline_errors"))
      File.open(error_log, 'w') do |f|
        f.write <<END
{% capture asset_pipeline_error_content %}{% include asset_pipeline_errors.log %}{% endcapture %}
{% unless asset_pipeline_error_content contains "Liquid error" or asset_pipeline_error_content contains "not found in _includes directory" %}
{% include asset_pipeline_errors.log %}</span>
{% endunless %}
END
      end unless File.exists?(error_log)
    end

  end

end