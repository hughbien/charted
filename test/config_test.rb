require_relative 'helper'

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
