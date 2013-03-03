require File.expand_path('lib/charted', File.dirname(__FILE__))

Charted.configure(ENV['RACK_ENV'] != 'test') do |c|
  c.email       'dev@localhost'
  c.db_adapter  'sqlite3'
  c.db_host     'localhost'
  c.db_username 'root'
  c.db_password 'secret'
  c.db_database 'db.sqlite3'
  c.sites       ['localhost', 'example.org']
end

if !ENV['CHARTED_CMD']
  map('/charted') { run Charted::App } 
end
