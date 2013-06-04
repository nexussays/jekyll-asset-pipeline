# Jekyll Asset Pipeline

## Overview

Jekyll Asset Pipeline is a lightweight way to run your assets (CSS, Javascript, etc) through various converters and minifiers when building your Jekyll site.

Perhaps you write all your stylesheets in SASS, your Javascript in CoffeScript and you want the output minified as well. All easy, and little to no configuration required.

## Setup

Grab this as a submodule in your Jekyll project repo:

```
git submodule add git://github.com/nexussays/jekyll-asset-pipeline.git _plugins/asset_pipeline
```

### Updating

To update, just navigate to the submodule directory and pull the latest changes.

```bash
cd _plugins/asset_pipeline
git pull origin master
```

## Requirements

In order to use the CSS and JS compression, you'll need to add two gems to your `Gemfile` and run `bundle install`

```ruby
source "http://rubygems.org"

# for asset conversion and compression
gem 'sass', '~> 3.2'
gem 'closure-compiler', '~> 1.1'
```

Or just install them directly if you'd prefer:

```bash
gem install sass --version "= 3.2"
gem install closure-compiler --version "= 1.1"
```

Alternatively, if you don't want those features, you can just delete `compress_css.rb` and `compress_js.rb`.

## Configuration

You only need to add the location of your assets directory to your Jekyll `_config.yml`. Just a single line.

```YAML
assets:  ./_assets
```

### Gitignore

You'll also want to add thse two lines to your `.gitignore`:

```
.asset_cache
asset_pipeline_errors*
```

## Usage

**No need to modify your templates or HTML with custom Liquid blocks.** The only changes are with your assets.

Each file in your assets directory (as defined in `_config.yml`) will be processed with the Converters in your Jekyll `_plugins` directory. **These are standard Jekyll Converters**, but the asset pipeline will run them on all files, not just ones with YAML "front-matter".

Several converters are included with this project, but any others you have in your `_plugins` dirctory will also be run on your assets.

To have several converters run on a single file, append multiple extensions to your files, eg `syntax-coloring.css.scss`

The above file will first run the highest-priority Converter that matches the `scss` extension, followed by the highest-priority Converter that matches the `css` extension. (If you don't have any additional converters other than what is part of this project, then the SASS converter runs and then the CSS minifier runs)


### Bundling

[in progress]

### Directory Structure

When the pipeline runs, your assets will be processed and copied to your project's destination directory in the same folder structure as your assets directory.

For example, if your project looks like this:

```
.
|-- _assets/
|   \-- assets/
|       |-- scripts/
|       |   \-- <bunch of TypeScript files>
|       \-- styles/
|           \-- <bunch of SCSS files>
|-- _includes/
|-- _layouts/
\-- etc...
```

Then the destination will look like this:

```
.
\-- _site/
    \-- assets/
        |-- scripts/
        |   \-- <bunch of Javascript files>
        \-- styles/
            \-- <bunch of CSS files>
```
Simple, eh?

### HTML Tags

You can reference the resulting files in your layouts using standard HTML since the output file names and locations are deterministic.

```HTML
<link rel="stylesheet" href="/assets/styles/syntax-coloring.css">
<script src="/assets/scripts/modernizr-2.6.2.js"></script>
```

### Asset Pipeline Errors

It can be very helpful to easily see any asset-related errors when Jekyll is watching your project with `jekyll server --watch`. To that end, there is a way to include asset errors on your pages so you don't have to switch to your command prompt to see them.

In your main layout file, right after the start of `<body>`, add this:

```
{% include asset_pipeline_errors %}
```

If there are errors in the asset pipeline, they will be visible on your pages, making it easy to see on refresh. If there are no errors, *nothing is added to the HTML*, so you can safely leave this in for production.

The error block can be styled using the id `#asset_pipeline_errors` like so:

```css
#asset_pipeline_errors
{
	background-color: red;
	color: white;
	font-weight: bold;
	font-family: "Consolas";
	font-size: 12px;
	white-space: pre;
	width: 100%;
	display: block;
}
```

If, for whatever reason, you don't want these two files to be generated as part of the asset pipeline (`asset_pipeline_errors`, the include file, and `asset_pipeline_errors.log`, which contains the log) just remove `asseterrorlog_generator.rb`.