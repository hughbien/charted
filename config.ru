require File.expand_path('lib/metrics', File.dirname(__FILE__))

Metrics.configure(ENV['RACK_ENV'] != 'test') do |c|
  c.email       'dev@localhost'
  c.db_adapter  'sqlite3'
  c.db_host     'localhost'
  c.db_username 'root'
  c.db_password 'secret'
  c.db_database 'db.sqlite3'
  c.sites       ['localhost', 'example.org']
end

if !ENV['METRICS_CMD']
  map('/metrics') { run Metrics::App } 
end
