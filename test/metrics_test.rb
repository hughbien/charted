ENV['RACK_ENV'] = 'test'

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
    Metrics::Visitor.destroy
    Metrics::Visit.destroy
  end

  def test_create
    site = Metrics::Site.create(:domain => 'localhost')
    visitor = Metrics::Visitor.create(:site => site)
    visit = Metrics::Visit.create(:visitor => visitor)
    assert_equal site, visit.site
    assert_equal [visit], site.visits
  end
end

class AppTest < MetricsTest
  include Rack::Test::Methods

  def setup
    Metrics::Site.destroy
    Metrics::Visitor.destroy
    Metrics::Visit.destroy
    clear_cookies
  end

  def test_environment
    assert_equal :test, Metrics::App.environment
  end

  def test_metrics_js
    get '/?js'
    assert last_response.ok?
  end

  def test_metrics_new_visitor
    get '/?js'
    # assert_equal('bar', rack_mock_session.cookie_jar['foo'])
  end

  def test_metrics_old_visitor
    set_cookie 'foo=bar'
    get '/?js'
    # assert_equal('bar', rack_mock_session.cookie_jar['foo'])
  end

  private
  def app
    @app ||= Rack::Server.new.app
  end
end
