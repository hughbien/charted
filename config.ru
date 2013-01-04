require File.expand_path('lib/metrics', File.dirname(__FILE__))

Metrics.configure do |c|
  c.email       'dev@localhost'
  c.db_adapter  'sqlite3'
  c.db_host     'localhost'
  c.db_username 'root'
  c.db_password 'secret'
  c.db_database 'db.sqlite3'
  c.sites       ['localhost']
end

run Metrics::App if !ENV['METRICS_CMD']
