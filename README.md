Description
===========

Metrics is a minimal web traffic analytics app.  Still under development!

Installation
============

    $ gem install metrics

Setup a `config.ru` file and run it like any other Sinatra application.

    require 'rubygems'
    require 'metrics'

    Metrics.configure do |c|
      c.email        'john@mailinator.com'      # production exceptions are sent here
      c.delete_after 365                        # only keep a years worth of data
      c.db_adapter   'mysql'
      c.db_host      'localhost'
      c.db_username  'root'
      c.db_password  'secret'
      c.db_database  'metrics'
      c.sites        ['hughbien.com', 'example.com']
    end

    run Metrics::App if !ENV['METRICS_CMD']

Stick this in your `bashrc` or `zshrc`:

    METRICS_CONFIG='/path/to/config.ru'

Then initialize the database:

    $ metrics --migrate

The app should be mounted to `/metrics` path on your domain.  Then in your app,
include the script right before the closing `</body>` tag:

    <script src="/metrics/script.js" async></script>

If you concatenate your JavaScript, you can generate the `script.js` file and
add it to your project.  The downside being when you update the metrics gem,
you'll also have to remember to update the JavaScript:

    $ metrics --js > /path/to/my/project/public/metrics.js

Updating
========

    $ gem install metrics

Usage
=====

The web application is for end users, to get information about your traffic use
the included command line application.

    $ metrics --help
    $ metrics --site hugh # just needs the first few letters to distinguish

Development
===========

Put this in your `zshrc` or `bashrc`:

    export METRICS_CONFIG="/path/to/metrics/config.ru"

Then run:

    $ ./metrics --migrate
    $ shotgun

Head on over to `http://localhost:9393/metrics/prime.html`.  This is where
recordings should occur.

Tests are setup to run via `ruby test/*_test.rb` or via `rake`.

TODO
====

* track browsers, OS (unique only)
* track searches/found (total + unique)
* track geolocation (unique only)
* add CLI for pulling stats out
* add event tracking
* add funnel conversion tracking
* add AB testing
* add stats summary for AB tests
* add deletion via CLI
* add deletion every N days for fresh data
* add syncing for local dashboard
* add `--js` option
* optimize with If-Not-Modified or img instead of script
* ignore switch for developers
* setting for mounting on other paths besides `/metrics`
* deploy task in Rakefile for development

License
=======

Copyright Hugh Bien - http://hughbien.com.
Released under BSD License, see LICENSE.md for more info.
