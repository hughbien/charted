require File.expand_path('lib/metrics', File.dirname(__FILE__))
require 'rake/testtask'
require 'dm-migrations'

task :default => :test

Rake::TestTask.new do |t|
  t.pattern = 'test/*_test.rb'
end

task :build do
  `gem build metrics.gemspec`
end

task :clean do
  rm Dir.glob('*.gem')
end

task :push => :build do
  `gem push metrics-#{Metrics::VERSION}.gem`
end

task :geoip do
  rm 'geoip.dat'
  `curl "http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz" > geoip.dat.gz`
  `gunzip geoip.dat.gz`
end
