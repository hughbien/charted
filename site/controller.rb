require 'rubygems'
require 'homeostasis'

Stasis::Options.set_template_option 'scss', Compass.sass_engine_options
Homeostasis::Asset.concat 'all.css', %w(styles.css)
Homeostasis::Asset.concat 'all.js', %w(jquery.js script.js)
Homeostasis::Sitemap.config(url: 'http://chartedrb.com')

ignore /\/_.*/
ignore /\/\.saas-cache\/.*/
ignore /.*\.scssc/
