require_relative 'helper'

class ModelTest < ChartedTest
  def test_create
    site = Charted::Site.create(domain: 'localhost')
    visitor = Charted::Visitor.create(
      site: site,
      bucket: 0,
      ip_address: '67.188.42.140',
      user_agent:
        'Mozilla/5.0 (X11; Linux i686; rv:14.0) Gecko/20100101 Firefox/14.0.1')
    visit = Charted::Visit.create(
      visitor: visitor,
      path: '/',
      title: 'Prime',
      referrer: 'http://www.google.com?q=Charted+Test')

    assert_equal(site, visit.site)
    assert_equal([visit], visitor.visits)
    assert_equal('Charted Test', visit.search_terms)
    assert_match(/^\w{5}$/, visitor.secret)
    assert_equal("#{visitor.id}-#{visitor.bucket}-#{visitor.secret}", visitor.cookie)
    assert_equal('Linux', visitor.platform)
    assert_equal('Firefox', visitor.browser)
    assert_equal('14.0.1', visitor.browser_version)

    assert_equal(visitor, site.visitor_with_cookie(visitor.cookie))
    assert_nil(site.visitor_with_cookie("#{visitor.id}-zzzzz"))
    assert_nil(site.visitor_with_cookie("0-zzzzz"))
    assert_nil(site.visitor_with_cookie(nil))

    event = visitor.make_events('User Clicked').first
    assert_equal(site, event.site)
    assert_equal(visitor, event.visitor)
    assert_equal('User Clicked', event.label)

    conversion = visitor.start_conversions('User Purchased;User Abandon').first
    visitor.start_conversions('User Purchased') # no effect
    assert_equal(2, visitor.conversions.length)
    assert_equal(site, conversion.site)
    assert_equal(visitor, conversion.visitor)
    assert_equal('User Purchased', conversion.label)
    refute(conversion.ended?)
    visitor.end_goals('User Purchased')
    conversion.refresh
    assert(conversion.ended?)
    visitor.end_goals('Nonexistant') # no effect
    assert_equal(2, visitor.conversions.length)

    experiment = visitor.start_experiments('User Next:A').first
    visitor.start_experiments('User Next:A') # no effect
    visitor.start_experiments('User Next:B') # changes bucket
    experiment.refresh
    assert_equal(1, visitor.experiments.length)
    assert_equal(site, experiment.site)
    assert_equal(visitor, experiment.visitor)
    assert_equal('User Next', experiment.label)
    assert_equal('B', experiment.bucket)
    refute(experiment.ended?)
    visitor.end_goals('User Next')
    experiment.refresh
    assert(experiment.ended?)
    visitor.end_goals('Nonexistant') # no effect
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
