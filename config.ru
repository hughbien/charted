require File.expand_path('lib/charted', File.dirname(__FILE__))

Charted.configure do |c|
  c.delete_after  365
  c.sites        ['localhost', 'example.org']
  c.error_email  'dev@localhost'
  c.db_options(
    adapter: 'sqlite',
    host: 'localhost',
    username: 'root',
    password: 'secret',
    database: 'db.sqlite3')
  c.email_options(via: :sendmail)
end

if !ENV['CHARTED_CMD']
  map('/charted') { run Charted::App } 
end
