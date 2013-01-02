require File.expand_path('../lib/metrics', File.dirname(__FILE__))
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

class MetricsTest < MiniTest::Unit::TestCase
  def setup
    Metrics.configure(false) do |c|
      c.email       'dev@localhost'
      c.logging     File.expand_path('../temp/test.log', File.dirname(__FILE__))
      c.db_adapter  'sqlite3'
      c.db_host     'localhost'
      c.db_username 'root'
      c.db_password 'secret'
      c.db_database 'db.sqlite3'
      c.sites       ['localhost']
    end
    Pony.mail(nil)
  end

  def teardown
    FileUtils.rm_rf(File.expand_path('../temp', File.dirname(__FILE__)))
  end
end

class ConfigTest < MetricsTest
  def test_db
    assert_equal('dev@localhost', Metrics.config.email)
    assert_equal(
      File.expand_path('../temp/test.log', File.dirname(__FILE__)),
      Metrics.config.logging)
    assert_equal('sqlite3', Metrics.config.db_adapter)
    assert_equal('localhost', Metrics.config.db_host)
    assert_equal('root', Metrics.config.db_username)
    assert_equal('secret', Metrics.config.db_password)
    assert_equal('db.sqlite3', Metrics.config.db_database)
    assert_equal(['localhost'], Metrics.config.sites)
  end
end

class ModelTest < MetricsTest
  def teardown
    Metrics::Site.destroy
    Metrics::Visit.destroy
  end

  def test_site
    site = Metrics::Site.create(:domain => 'localhost')
    refute(site.nil?)
  end

  def test_visit
    site = Metrics::Site.create(:domain => 'localhost')
    visit = Metrics::Visit.create(:site => site)
    refute(visit.nil?)
  end
end

class AppTest < MetricsTest
  include Rack::Test::Methods

  def test_metrics_js
    get '/metrics.js'
    assert last_response.ok?
  end

  private
  def app
    @app ||= Rack::Server.new.app
  end
end
