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
      c.db_database 'test.sqlite3'
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
    assert_equal('test.sqlite3', Metrics.config.db_database)
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
    visit = Metrics::Visit.create(
      :visitor => visitor, :path => '/', :title => 'Prime')
    assert_equal(site, visit.site)
    assert_equal([visit], site.visits)
    assert_match(/^\w{5}$/, visitor.secret)
    assert_equal("#{visitor.id}-#{visitor.secret}", visitor.cookie)

    assert_equal(visitor, Metrics::Visitor.get_by_cookie(site, visitor.cookie))
    assert_nil(Metrics::Visitor.get_by_cookie(site, "#{visitor.id}-zzzzz"))
  end

  def test_unique_identifier
    assert_match(/^\w{5}$/, Metrics::Visitor.generate_secret)
  end
end

class AppTest < MetricsTest
  include Rack::Test::Methods

  def setup
    Metrics::Site.destroy
    Metrics::Visitor.destroy
    Metrics::Visit.destroy
    clear_cookies

    @site = Metrics::Site.create(:domain => 'example.org')
    @params = {:path => '/', :title => 'Prime'}
  end

  def test_environment
    assert_equal(:test, Metrics::App.environment)
  end

  def test_bad_domain
    get '/metrics', @params, 'HTTP_HOST' => 'localhost'
    assert_equal(404, last_response.status)
    assert_equal(0, Metrics::Visitor.count)
    assert_equal(0, Metrics::Visit.count)
  end

  def test_new_visitor
    get '/metrics', @params
    assert(last_response.ok?)
    assert_equal(1, Metrics::Visitor.count)
    assert_equal(1, Metrics::Visit.count)

    visitor = Metrics::Visitor.first
    visit = Metrics::Visit.first
    assert_equal(@site, visitor.site)
    assert_equal(@site, visit.site)
    assert_equal(visitor.cookie, rack_mock_session.cookie_jar['metrics'])
  end

  def test_old_visitor
    visitor = Metrics::Visitor.create(:site => @site)
    visit = Metrics::Visit.create(
      :visitor => visitor, :path => '/', :title => 'Prime')
    set_cookie("metrics=#{visitor.cookie}")

    get '/metrics', @params
    assert(last_response.ok?)
    assert_equal(1, Metrics::Visitor.count)
    assert_equal(2, Metrics::Visit.count)
    assert_equal(visitor.cookie, rack_mock_session.cookie_jar['metrics'])
  end

  def test_visitor_bad_cookie
    visitor = Metrics::Visitor.create(:site => @site)
    visit = Metrics::Visit.create(
      :visitor => visitor, :path => '/', :title => 'Prime')
    set_cookie("metrics=#{visitor.id}-zzzzz")

    get '/metrics', @params
    assert(last_response.ok?)
    assert_equal(2, Metrics::Visitor.count)
    assert_equal(2, Metrics::Visit.count)
    refute_equal(visitor.cookie, rack_mock_session.cookie_jar['metrics'])
  end

  private
  def app
    @app ||= Rack::Server.new.app
  end
end
