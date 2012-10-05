require File.expand_path('helper', File.dirname(__FILE__))

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
