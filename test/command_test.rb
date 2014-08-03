require_relative 'helper'

class CommandTest < ChartedTest
  def setup
    super
    @cmd = Charted::Command.new
    @cmd.config_loaded = true
    Charted::Site.destroy
    Charted::Visitor.destroy
    Charted::Visit.destroy
    Charted::Event.destroy
    Charted::Conversion.destroy
    Charted::Experiment.destroy
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

  def test_clean
    site = Charted::Site.first(domain: 'localhost')
    visitor = site.visitors.create
    visitor.events.create(label: 'Label')
    visitor.conversions.create(label: 'Label')
    visitor.experiments.create(label: 'Label', bucket: 'A')
    @cmd.output = nil
    @cmd.clean
    visitor.reload
    assert_equal(1, visitor.events.size)
    assert_equal(1, visitor.conversions.size)
    assert_equal(1, visitor.experiments.size)

    @cmd.output = nil
    @cmd.clean('Label')
    visitor.reload
    assert_equal(0, visitor.events.size)
    assert_equal(0, visitor.conversions.size)
    assert_equal(0, visitor.experiments.size)
  end

  def test_dashboard
    assert_raises(Charted::ExitError) { @cmd.dashboard }
    assert_equal(['Please specify website with --site'], @cmd.output)
    
    @cmd.output = nil
    @cmd.site = 'localhost'
    @cmd.dashboard
  end

  def test_js
    @cmd.output = nil
    @cmd.js
    assert_match("var Charted", @cmd.output[0])
  end

  def test_format
    assert_equal('-10,200', @cmd.send(:format, -10200))
    assert_equal('-1', @cmd.send(:format, -1))
    assert_equal('1', @cmd.send(:format, 1))
    assert_equal('1,200,300', @cmd.send(:format, 1200300))
  end
end
