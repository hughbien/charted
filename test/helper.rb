ENV['RACK_ENV'] = 'test'

require_relative '../lib/charted'
require 'minitest/autorun'
require 'rack'
require 'rack/test'
require 'rack/server'
require 'fileutils'

Charted.configure do |c|
  c.delete_after  365
  c.error_email   'dev@localhost'
  c.sites         ['localhost']
  c.db_options    'sqlite::memory'
  c.email_options(via: :sendmail)
end
Charted::Migrate.run

module Pony
  def self.mail(fields)
    Charted::Visit.select_all.delete
    Charted::Event.select_all.delete
    Charted::Conversion.select_all.delete
    Charted::Experiment.select_all.delete
    Charted::Visitor.select_all.delete
    Charted::Site.select_all.delete
    @last_mail = fields
  end

  def self.last_mail
    @last_mail
  end
end

class ChartedTest < Minitest::Test
  def setup
    Pony.mail(nil)
  end

  def teardown
    FileUtils.rm_rf(File.expand_path('../temp', File.dirname(__FILE__)))
  end
end
