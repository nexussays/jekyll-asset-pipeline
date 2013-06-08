# Jekyll Asset Pipeline

## Overview

Jekyll Asset Pipeline is a lightweight way to run your assets (CSS, Javascript, etc) through various converters and minifiers when building your Jekyll site.

Perhaps you write all your stylesheets in SASS, your Javascript in CoffeScript and you want the output minified as well. All easy, and little to no configuration required.

## Installing

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

### Ruby Gems

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

### Jekyll Configuration

You only need to add the location of your assets directory to your Jekyll `_config.yml`. You'll want to make sure this is a directory that Jekyll ignores by default by prefixing it with `_` or `.`.

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

No need to modify your templates or HTML with custom Liquid blocks. The only changes are with your assets.

### Converters

Converters are regular [Jekyll Converters](http://jekyllrb.com/docs/plugins/#converters), with the one change that they will run on *everything in your assets directory*, regardless of whether or not they have YAML front-matter.

Several converters are included with this project, but any others in your `_plugins` dirctory will also be run on your assets.

**If you write a new converter, send a pull request so we can add it to the core project!**

### Running Mulitiple Converters on Assets 

To have several converters run on a single file, append multiple extensions to your files.

For example, the file `syntax-coloring.css.scss` will first run the highest-priority Converter that matches the `scss` extension, followed by the highest-priority Converter that matches the `css` extension.

> If you don't have any additional converters other than what is part of this project, then in the above example, first the SASS converter runs and then the CSS minifier runs.

### Bundling

To bundle assets into a single file, name them with the same prefix. For example, these files:

```
main.fonts.scss
main.scss
main.structure.scss
main.syntax.color.scss
main.syntax.color-generic.scss
```

Will result in a single output file named `main.css`.

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
<!--
	source files:
		/_assets/assets/styles/main.fonts.scss
		/_assets/assets/styles/main.scss
		/_assets/assets/styles/main.structure.scss
		/_assets/assets/styles/main.syntax.color.scss
		/_assets/assets/styles/main.syntax.color-generic.scss
-->
<link rel="stylesheet" href="/assets/styles/main.css">

<!--
	source files:
		/_assets/assets/scripts/my_site.ts
-->
<script src="/assets/scripts/my_site.js"></script>
```

## Errors

It can be very helpful to easily see any asset-related errors when Jekyll is watching your project with `jekyll server --watch`. To that end, there is a way to include asset errors on your pages so you don't have to switch to your command prompt to see them.

In your main layout file, right after the start of `<body>`, add this:

```
{% include asset_pipeline_errors %}
```

If there are errors in the asset pipeline, they will be visible on your pages, making it easy to see on refresh. If there are no errors, *nothing is added to the HTML*, so you can safely leave this in for production.

The error block has styling to make it bright red, but you can hook in additional styling by using the id `#asset_pipeline_errors`.

> If, for whatever reason, you don't want these two files to be generated as part of the asset pipeline (`asset_pipeline_errors`, the include file, and `asset_pipeline_errors.log`, which contains the log) just delete `asseterrorlog_generator.rb`.
