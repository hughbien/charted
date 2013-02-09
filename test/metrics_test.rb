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
  def setup
    Metrics::Site.destroy
    Metrics::Visitor.destroy
    Metrics::Visit.destroy
  end

  def test_create
    site = Metrics::Site.create(:domain => 'localhost')
    visitor = Metrics::Visitor.create(
      :site => site,
      :ip_address => '67.188.42.140',
      :user_agent =>
        'Mozilla/5.0 (X11; Linux i686; rv:14.0) Gecko/20100101 Firefox/14.0.1')
    visit = Metrics::Visit.create(
      :visitor => visitor,
      :path => '/',
      :title => 'Prime',
      :referrer => 'http://www.google.com?q=Metrics+Test')
    assert_equal(site, visit.site)
    assert_equal([visit], site.visits)
    assert_equal('Metrics Test', visit.search_terms)
    assert_match(/^\w{5}$/, visitor.secret)
    assert_equal("#{visitor.id}-#{visitor.secret}", visitor.cookie)
    assert_equal('Linux', visitor.platform)
    assert_equal('Firefox', visitor.browser)
    assert_equal('14.0.1', visitor.browser_version)

    assert_equal(visitor, Metrics::Visitor.get_by_cookie(site, visitor.cookie))
    assert_nil(Metrics::Visitor.get_by_cookie(site, "#{visitor.id}-zzzzz"))
  end

  def test_unique_identifier
    assert_match(/^\w{5}$/, Metrics::Visitor.generate_secret)
  end

  def test_user_agents
    visitor = Metrics::Visitor.new

    visitor.user_agent = 'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0)'
    assert_equal('Internet Explorer', visitor.browser)
    assert_equal('7.0', visitor.browser_version)
    assert_equal('Windows', visitor.platform)

    visitor.user_agent = 'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en) AppleWebKit/125.2 (KHTML, like Gecko) Safari/125.8'
    assert_equal('Safari', visitor.browser)
    assert_equal('1.2.2', visitor.browser_version)
    assert_equal('Macintosh', visitor.platform)

    visitor.user_agent = 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.1.19) Gecko/20081216 Ubuntu/8.04 (hardy) Firefox/2.0.0.19'
    assert_equal('Firefox', visitor.browser)
    assert_equal('2.0.0.19', visitor.browser_version)
    assert_equal('Linux', visitor.platform)
  end

  def test_blanks
    site = Metrics::Site.create(:domain => 'localhost')
    visitor = Metrics::Visitor.create(
      :site => site,
      :user_agent => '',
      :ip_address => '')
    visit = Metrics::Visit.create(
      :visitor => visitor,
      :path => '/',
      :title => 'Prime',
      :referrer => '')
    assert(site.id)
    assert(visitor.id)
    assert(visit.id)
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
    @params = {
      :path => '/',
      :title => 'Prime',
      :referrer => 'localhost',
      :resolution => '1280x800'
    }
    @env = {
      'HTTP_USER_AGENT' =>
        'Mozilla/5.0 (X11; Linux i686; rv:14.0) Gecko/20100101 Firefox/14.0.1',
      'REMOTE_ADDR' => '67.188.42.140'
    }
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
    get '/metrics', @params, @env
    assert(last_response.ok?)
    assert_equal(1, Metrics::Visitor.count)
    assert_equal(1, Metrics::Visit.count)

    visitor = Metrics::Visitor.first
    visit = Metrics::Visit.first
    assert_equal(@site, visitor.site)
    assert_equal(@site, visit.site)
    assert_equal('Prime', visit.title)
    assert_equal('/', visit.path)
    assert_equal('localhost', visit.referrer)
    assert_equal('1280x800', visitor.resolution)
    assert_equal('United States', visitor.country)
    assert_equal(visitor.cookie, rack_mock_session.cookie_jar['metrics'])
  end

  def test_old_visitor
    visitor = Metrics::Visitor.create(:site => @site)
    visit = Metrics::Visit.create(
      :visitor => visitor, :path => '/', :title => 'Prime')
    set_cookie("metrics=#{visitor.cookie}")

    get '/metrics', @params, @env
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

    get '/metrics', @params, @env
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

class CommandTest < MetricsTest
  def setup
    @cmd = Metrics::Command.new
    @cmd.config_loaded = true
    Metrics::Site.destroy
    Metrics::Visitor.destroy
    Metrics::Visit.destroy
    Metrics::Site.create(:domain => 'localhost')
    Metrics::Site.create(:domain => 'example.org')
  end

  def test_site
    assert_raises(Metrics::ExitError) { @cmd.site = 'nomatch' }
    assert_equal(['No sites matching "nomatch"'], @cmd.output)
    assert_nil(@cmd.site)

    @cmd.output = nil
    assert_raises(Metrics::ExitError) { @cmd.site = 'l' }
    assert_equal(['"l" ambiguous: localhost, example.org'], @cmd.output)

    @cmd.site = 'local'
    assert_equal('localhost', @cmd.site.domain)

    @cmd.site = 'ample'
    assert_equal('example.org', @cmd.site.domain)
  end

  def test_dashboard
    assert_raises(Metrics::ExitError) { @cmd.dashboard }
    assert_equal(['Please specify website with --site'], @cmd.output)
    
    @cmd.output = nil
    @cmd.site = 'localhost'
    @cmd.dashboard
  end

  def test_format
    assert_equal('-10,200', @cmd.send(:format, -10200))
    assert_equal('-1', @cmd.send(:format, -1))
    assert_equal('1', @cmd.send(:format, 1))
    assert_equal('1,200,300', @cmd.send(:format, 1200300))
  end
end
