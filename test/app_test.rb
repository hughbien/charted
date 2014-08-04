require_relative 'helper'

class AppTest < ChartedTest
  include Rack::Test::Methods

  def setup
    super
    clear_cookies
    @site = Charted::Site.create(:domain => 'example.org')
    @params = {
      :bucket => 1,
      :path => '/',
      :title => 'Prime',
      :referrer => 'http://localhost/?k=v',
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

  def test_override_domain
    site = Charted::Site.create(domain: 'chartedrb.com')
    get '/charted', @params.merge(domain: 'chartedrb.com'), @env
    assert(last_response.ok?)
    assert_equal(1, Charted::Visitor.count)
    assert_equal('chartedrb.com', Charted::Visitor.first.site.domain)
  end

  def test_error
    raises_error = lambda { |*args| raise('Stubbed Error') }
    Charted::Site.stub(:first, raises_error) do
      assert_raises(RuntimeError) do
        get '/charted', @params, @env
      end
    end
    mail = Pony.last_mail
    assert_equal('dev@localhost', mail[:to])
    assert_equal('[Charted Error] Stubbed Error', mail[:subject])
    assert(mail[:body])
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
    assert_equal('http://localhost/?k=v', visit.referrer)
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
    get '/charted/record', events: 'Event Label;Event Label 2'
    assert_equal(404, last_response.status)

    visitor = @site.add_visitor({})
    set_cookie("charted=#{visitor.cookie}")
    get '/charted/record', events: 'Event Label;Event Label 2'
    assert(last_response.ok?)
    assert_equal(2, Charted::Event.count)

    event = Charted::Event.first(label: 'Event Label')
    assert_equal(@site, event.site)
    assert_equal(visitor, event.visitor)
    assert_equal('Event Label', event.label)

    event2 = Charted::Event.first(label: 'Event Label 2')
    assert(event2)
    assert_equal('Event Label 2', event2.label)
  end

  def test_conversions
    visitor = @site.add_visitor({})
    set_cookie("charted=#{visitor.cookie}")
    get '/charted', @params.merge(conversions: 'Logo Clicked;Button Clicked'), @env
    assert(last_response.ok?)
    assert_equal(2, Charted::Conversion.count)

    logo = visitor.conversions_dataset.first(label: 'Logo Clicked')
    button = visitor.conversions_dataset.first(label: 'Button Clicked')
    refute(logo.ended?)
    refute(button.ended?)

    get '/charted/record', goals: 'Logo Clicked;Button Clicked'
    assert(last_response.ok?)
    logo.reload
    button.reload
    assert(logo.ended?)
    assert(button.ended?)
  end

  def test_experiments
    visitor = @site.add_visitor({})
    set_cookie("charted=#{visitor.cookie}")
    get '/charted', @params.merge(experiments: 'Logo:A;Button:B'), @env
    assert(last_response.ok?)
    assert_equal(2, Charted::Experiment.count)

    logo = visitor.experiments_dataset.first(label: 'Logo')
    button = visitor.experiments_dataset.first(label: 'Button')
    assert_equal('Logo', logo.label)
    assert_equal('A', logo.bucket)
    refute(logo.ended?)
    assert_equal('Button', button.label)
    assert_equal('B', button.bucket)
    refute(button.ended?)

    get '/charted/record', goals: 'Logo;Button'
    assert(last_response.ok?)
    logo.reload
    button.reload
    assert(logo.ended?)
    assert(button.ended?)
  end

  private
  def app
    @app ||= Rack::Server.new.app
  end
end
