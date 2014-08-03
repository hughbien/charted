require 'rake/testtask'

task default: :test

Rake::TestTask.new do |t|
  t.pattern = 'test/*_test.rb'
end

desc 'Build charted gem'
task :build do
  `gem build charted.gemspec`
end

desc 'Remove build artifacts'
task :clean do
  rm Dir.glob('*.gem')
end

desc 'Push gem to rubygems.org'
task push: :build do
  require_relative 'lib/charted/version'
  `gem push charted-#{Charted::VERSION}.gem`
end

desc 'Download latest geoip.dat'
task :geoip do
  rm 'geoip.dat'
  `curl "http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz" > geoip.dat.gz`
  `gunzip geoip.dat.gz`
end

namespace :site do
  task default: :build

  desc 'Build site'
  task :build do
    `cd site && stasis`
  end

  desc 'Push site to chartedrb.com'
  task push: [:clean, :build] do
    `rsync -avz --delete site/public/ chartedrb.com:webapps/chartedrb`
  end

  desc 'Remove built site artifacts'
  task :clean do
    rm_r 'site/public'
  end
end
