Description
===========

Charted is a minimal web traffic analytics app.  Still under development!

Installation
============

    $ gem install charted

Setup a `config.ru` file and run it like any other Sinatra application.

    require 'rubygems'
    require 'charted'

    Charted.configure do |c|
      c.email        'john@mailinator.com'      # production exceptions are sent here
      c.delete_after 365                        # only keep a years worth of data
      c.db_adapter   'mysql'
      c.db_host      'localhost'
      c.db_username  'root'
      c.db_password  'secret'
      c.db_database  'charted'
      c.sites        ['hughbien.com', 'example.com']
    end

    run Charted::App if !ENV['CHARTED_CMD']

Stick this in your `bashrc` or `zshrc`:

    CHARTED_CONFIG='/path/to/config.ru'

Then initialize the database:

    $ charted --migrate

The app should be mounted to `/charted` path on your domain.  Then in your app,
include the script right before the closing `</body>` tag:

    <script src="/charted/script.js" async></script>

If you concatenate your JavaScript, you can generate the `script.js` file and
add it to your project.  The downside being when you update the charted gem,
you'll also have to remember to update the JavaScript:

    $ charted --js > /path/to/my/project/public/charted.js

Updating
========

    $ gem install charted

Usage
=====

The web application is for end users, to get information about your traffic use
the included command line application.

    $ charted --help
    $ charted --dashboard --site hugh # just needs the first few letters
    +-------+--------+--------------------------------------+
    | Total | Unique | Visits                               |
    +-------+--------+--------------------------------------+
    | 7,012 |  5,919 | February 2013                        |
    | 6,505 |  4,722 | January 2013                         |
    | 5,342 |  3,988 | December 2012                        |
    ...

Development
===========

Put this in your `zshrc` or `bashrc`:

    export CHARTED_CONFIG="/path/to/charted/config.ru"

Then run:

    $ ./charted --migrate
    $ shotgun

Head on over to `http://localhost:9393/charted/prime.html`.  This is where
recordings should occur.

Tests are setup to run via `ruby test/*_test.rb` or via `rake`.

TODO
====

* ignore cookie for developers
* deploy task in Rakefile for development
* consider indexes on created_at, *
* hide empty tables
* add date range option

License
=======

`geoip.dat` is provided by MaxMind at <http://dev.maxmind.com/geoip/geolite>.

Copyright Hugh Bien - http://hughbien.com.
Released under BSD License, see LICENSE.md for more info.
