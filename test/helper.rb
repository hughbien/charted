ENV['RACK_ENV'] = 'test'

require_relative '../lib/charted'
require 'dm-migrations'
require 'minitest/autorun'
require 'rack'
require 'rack/test'
require 'rack/server'
require 'fileutils'

DataMapper.setup(:default, 'sqlite::memory:')
DataMapper.auto_migrate!

module Pony
  def self.mail(fields)
    @last_mail = fields
  end

  def self.last_mail
    @last_mail
  end
end

class ChartedTest < Minitest::Test
  def setup
    Charted.configure(false) do |c|
      c.delete_after 365
      c.email        'dev@localhost'
      c.db_adapter   'sqlite3'
      c.db_host      'localhost'
      c.db_username  'root'
      c.db_password  'secret'
      c.db_database  'test.sqlite3'
      c.sites        ['localhost']
    end
    Pony.mail(nil)
  end

  def teardown
    FileUtils.rm_rf(File.expand_path('../temp', File.dirname(__FILE__)))
  end
end
