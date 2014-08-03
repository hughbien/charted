require_relative 'helper'

class ConfigTest < ChartedTest
  def test_config
    assert_equal(365, Charted.config.delete_after)
    assert_equal('dev@localhost', Charted.config.email)
    assert_equal('sqlite::memory', Charted.config.db_options)
    assert_equal(['localhost'], Charted.config.sites)
  end
end
