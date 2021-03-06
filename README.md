# Description

Charted is a minimal web traffic analytics app.

# Installation

    $ gem install charted

Also install the relevant database adapter, depending on which db you plan to use:

    $ gem install dm-mysql-adapter

Setup a `config.ru` file and run it like any other Sinatra application.

    require 'rubygems'
    require 'charted'

    Charted.configure do |c|
      c.delete_after 365                             # only keep a years worth of data
      c.error_email  'john@mailinator.com'           # production exceptions are sent here
      c.sites        ['hughbien.com', 'example.com']
      c.db_options(                                  # database config
        adapter:     'postgres',
        host:        'localhost',
        username:    'root',
        password:    'secret',
        database:    'charted')
      c.email_options(                               # error email config (see Pony gem for options)
        from:        'errors@mailinator.com',
        via:         :smtp,
        via_options: {host: 'smtp.example.org'})
    end

    run Charted::App if !ENV['CHARTED_CMD']

Stick this in your `bashrc` or `zshrc`:

    CHARTED_CONFIG='/path/to/config.ru'

Then initialize the database:

    $ charted --migrate

The app should be mounted to `/charted` path on your domain

In your app, generate a `charted.js` file.  This can be safely concatenated with
you other JavaScript assets.

    $ charted --js > /path/to/my/project/public/charted.js

# Updating

    $ gem install charted
    
You may need to generate a `charted.js` file again:

    $ charted --js > /path/to/my/project/public/charted.js

# Usage

The web application is for end users, to get information about your traffic use
the included command line application.

    $ charted --site hugh # just needs the first few letters
    +-------+--------+--------------------------------------+
    | Total | Unique | Visits                               |
    +-------+--------+--------------------------------------+
    | 7,012 |  5,919 | February 2013                        |
    | 6,505 |  4,722 | January 2013                         |
    | 5,342 |  3,988 | December 2012                        |
    ...

Basic tracking of common stats like visits, referrers, or user agents are done
automatically.  You can also track events, conversions, and experiments.

Events can be recorded with JavaScript:

    Charted.events("1st Button Clicked");
    Charted.events("1st Button Clicked", "2nd Button Clicked");

To start a conversion, you'll need to set the `data-conversions` attribute of
the `<body>` element:

    <body data-conversions="RSS Subscribed; Item Purchased">

Just separate goal names with a semi-colon.  When the conversion goal has been
reached:

    Charted.goals("RSS Subscribed");
    Charted.goals("RSS Subscribed", "Item Purchased"); // calls can be batched

Experiments use the `data-experiments` attribute and use the format
`experiment: bucket1, bucket2, ...`:

    <body data-experiments="Buy Button: Blue, Green, Red">

The included JavaScript will automatically select a bucket for this user and
append a relevant class name to the `<body>` element like:

    <body class="buy-button-green">

The class name is just the experiment label and bucket lowercased with spaces
replaced with dashes.  Use CSS to tweak the buy button.  When a user clicks
on a button, use JavaScript to send a message to the server:

    Charted.goals("Buy Button");

Running `charted --clean` will prune the database of old data.  I recommend
putting this as a cronjob.  It can also be used to remove bad entries in the
events/conversions/experiments table:

    charted --clean "Buy Button"

# Rack Extensions

I recommend using these extensions with Charted:

* [Rack Timeout](https://github.com/heroku/rack-timeout)
* [Rack Throttle](https://github.com/datagraph/rack-throttle)

# Development

Put this in your `zshrc` or `bashrc`:

    export CHARTED_CONFIG="/path/to/charted/config.ru"

Then run:

    $ bin/charted --migrate
    $ shotgun

Head on over to `http://localhost:9393/charted/prime.html`.  This is where
recordings should occur.

Tests are setup to run via `ruby test/*_test.rb` or via `rake`.

# TODO

* handle case where visitor visits "/charted" or any other route directly (bad input)
* record/display uniques for pages, etc... perhaps --unique option
* add --limit NUMBER to limit number of rows per table outputted
* add date range options (--start "3 days ago" --end "1 day ago")

# License

`geoip.dat` is provided by MaxMind at <http://dev.maxmind.com/geoip/geolite>.

Copyright Hugh Bien - http://hughbien.com.
Released under BSD License, see LICENSE.md for more info.
