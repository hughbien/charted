ENV['RACK_ENV'] = 'test'

require File.expand_path('../lib/charted', File.dirname(__FILE__))
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

class ChartedTest < MiniTest::Unit::TestCase
  def setup
    Charted.configure(false) do |c|
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

class ConfigTest < ChartedTest
  def test_db
    assert_equal('dev@localhost', Charted.config.email)
    assert_equal('sqlite3', Charted.config.db_adapter)
    assert_equal('localhost', Charted.config.db_host)
    assert_equal('root', Charted.config.db_username)
    assert_equal('secret', Charted.config.db_password)
    assert_equal('test.sqlite3', Charted.config.db_database)
    assert_equal(['localhost'], Charted.config.sites)
  end
end

class ModelTest < ChartedTest
  def setup
    Charted::Site.destroy
    Charted::Visitor.destroy
    Charted::Visit.destroy
    Charted::Event.destroy
    Charted::Conversion.destroy
    Charted::Experiment.destroy
  end

  def test_create
    site = Charted::Site.create(domain: 'localhost')
    visitor = Charted::Visitor.create(
      site: site,
      ip_address: '67.188.42.140',
      user_agent:
        'Mozilla/5.0 (X11; Linux i686; rv:14.0) Gecko/20100101 Firefox/14.0.1')
    visit = Charted::Visit.create(
      visitor: visitor,
      path: '/',
      title: 'Prime',
      referrer: 'http://www.google.com?q=Charted+Test')

    assert_equal(site, visit.site)
    assert_equal([visit], site.visits)
    assert_equal('Charted Test', visit.search_terms)
    assert_match(/^\w{5}$/, visitor.secret)
    assert_equal("#{visitor.id}-#{visitor.secret}", visitor.cookie)
    assert_equal('Linux', visitor.platform)
    assert_equal('Firefox', visitor.browser)
    assert_equal('14.0.1', visitor.browser_version)

    assert_equal(visitor, site.visitor_with_cookie(visitor.cookie))
    assert_nil(site.visitor_with_cookie("#{visitor.id}-zzzzz"))
    assert_nil(site.visitor_with_cookie("0-zzzzz"))
    assert_nil(site.visitor_with_cookie(nil))

    event = visitor.events.create(label: 'User Clicked')
    assert_equal(site, event.site)
    assert_equal(visitor, event.visitor)
    assert_equal('User Clicked', event.label)

    conversion = visitor.start_conversion('User Purchased')
    visitor.start_conversion('User Purchased') # no effect
    assert_equal(1, visitor.conversions.length)
    assert_equal(site, conversion.site)
    assert_equal(visitor, conversion.visitor)
    assert_equal('User Purchased', conversion.label)
    refute(conversion.ended?)
    visitor.end_conversion('User Purchased')
    assert(conversion.ended?)
    visitor.end_conversion('Nonexistant')
    assert_equal(2, visitor.conversions.length)

    experiment = visitor.start_experiment('User Next', 'A')
    visitor.start_experiment('User Next', 'A') # no effect
    visitor.start_experiment('User Next', 'B') # changes bucket
    assert_equal(1, visitor.experiments.length)
    assert_equal(site, experiment.site)
    assert_equal(visitor, experiment.visitor)
    assert_equal('User Next', experiment.label)
    assert_equal('B', experiment.bucket)
    refute(experiment.ended?)
    visitor.end_experiment('User Next')
    assert(experiment.ended?)
    visitor.end_experiment('Nonexistant') # no effect
    assert_equal(1, visitor.experiments.length)
  end

  def test_unique_identifier
    assert_match(/^\w{5}$/, Charted::Visitor.generate_secret)
  end

  def test_user_agents
    visitor = Charted::Visitor.new

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
    site = Charted::Site.create(:domain => 'localhost')
    visitor = Charted::Visitor.create(
      :site => site,
      :user_agent => '',
      :ip_address => '')
    visit = Charted::Visit.create(
      :visitor => visitor,
      :path => '/',
      :title => 'Prime',
      :referrer => '')
    assert(site.id)
    assert(visitor.id)
    assert(visit.id)
  end
end

class AppTest < ChartedTest
  include Rack::Test::Methods

  def setup
    Charted::Site.destroy
    Charted::Visitor.destroy
    Charted::Visit.destroy
    Charted::Event.destroy
    Charted::Conversion.destroy
    Charted::Experiment.destroy
    clear_cookies

    @site = Charted::Site.create(:domain => 'example.org')
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
    assert_equal(:test, Charted::App.environment)
  end

  def test_bad_domain
    get '/charted', @params, 'HTTP_HOST' => 'localhost'
    assert_equal(404, last_response.status)
    assert_equal(0, Charted::Visitor.count)
    assert_equal(0, Charted::Visit.count)
  end

  def test_new_visitor
    get '/charted', @params, @env
    assert(last_response.ok?)
    assert_equal(1, Charted::Visitor.count)
    assert_equal(1, Charted::Visit.count)

    visitor = Charted::Visitor.first
    visit = Charted::Visit.first
    assert_equal(@site, visitor.site)
    assert_equal(@site, visit.site)
    assert_equal('Prime', visit.title)
    assert_equal('/', visit.path)
    assert_equal('localhost', visit.referrer)
    assert_equal('1280x800', visitor.resolution)
    assert_equal('United States', visitor.country)
    assert_equal(visitor.cookie, rack_mock_session.cookie_jar['charted'])
  end

  def test_old_visitor
    visitor = Charted::Visitor.create(:site => @site)
    visit = Charted::Visit.create(
      :visitor => visitor, :path => '/', :title => 'Prime')
    set_cookie("charted=#{visitor.cookie}")

    get '/charted', @params, @env
    assert(last_response.ok?)
    assert_equal(1, Charted::Visitor.count)
    assert_equal(2, Charted::Visit.count)
    assert_equal(visitor.cookie, rack_mock_session.cookie_jar['charted'])
  end

  def test_visitor_bad_cookie
    visitor = Charted::Visitor.create(:site => @site)
    visit = Charted::Visit.create(
      :visitor => visitor, :path => '/', :title => 'Prime')
    set_cookie("charted=#{visitor.id}-zzzzz")

    get '/charted', @params, @env
    assert(last_response.ok?)
    assert_equal(2, Charted::Visitor.count)
    assert_equal(2, Charted::Visit.count)
    refute_equal(visitor.cookie, rack_mock_session.cookie_jar['charted'])
  end

  def test_events # TODO: use correct HTTP methods?
    get '/charted/event', event: 'Event Label'
    assert_equal(404, last_response.status)

    visitor = @site.visitors.create
    set_cookie("charted=#{visitor.cookie}")
    get '/charted/event', event: 'Event Label'
    assert(last_response.ok?)
    assert_equal(1, Charted::Event.count)

    event = Charted::Event.first
    assert_equal(@site, event.site)
    assert_equal(visitor, event.visitor)
    assert_equal('Event Label', event.label)
  end

  private
  def app
    @app ||= Rack::Server.new.app
  end
end

class CommandTest < ChartedTest
  def setup
    @cmd = Charted::Command.new
    @cmd.config_loaded = true
    Charted::Site.destroy
    Charted::Visitor.destroy
    Charted::Visit.destroy
    Charted::Site.create(:domain => 'localhost')
    Charted::Site.create(:domain => 'example.org')
  end

  def test_site
    assert_raises(Charted::ExitError) { @cmd.site = 'nomatch' }
    assert_equal(['No sites matching "nomatch"'], @cmd.output)
    assert_nil(@cmd.site)

    @cmd.output = nil
    assert_raises(Charted::ExitError) { @cmd.site = 'l' }
    assert_equal(['"l" ambiguous: localhost, example.org'], @cmd.output)

    @cmd.site = 'local'
    assert_equal('localhost', @cmd.site.domain)

    @cmd.site = 'ample'
    assert_equal('example.org', @cmd.site.domain)
  end

  def test_dashboard
    assert_raises(Charted::ExitError) { @cmd.dashboard }
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
