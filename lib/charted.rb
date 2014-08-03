require 'bundler/setup'
require 'sinatra/base'
require 'dm-core'
require 'dm-types'
require 'dm-timestamps'
require 'dm-validations'
require 'dm-aggregates'
require 'date'
require 'digest/sha1'
require 'json'
require 'uri'
require 'geoip'
require 'pony'
require 'useragent'
require 'search_terms'
require 'dashes'

require_relative 'charted/app'
require_relative 'charted/command'
require_relative 'charted/config'
require_relative 'charted/model'
require_relative 'charted/version'

module Charted
  GEOIP = GeoIP.new("#{File.dirname(__FILE__)}/../geoip.dat")
  JS_FILE = "#{File.dirname(__FILE__)}/../public/charted/script.js"

  def self.prev_month(date, delta=1)
    date = Date.new(date.year, date.month, 1)
    delta.times { date = Date.new((date - 1).year, (date - 1).month, 1) }
    date
  end

  def self.next_month(date, delta=1)
    date = Date.new(date.year, date.month, 1)
    delta.times { date = Date.new((date + 32).year, (date + 32).month, 1) }
    date
  end
end
