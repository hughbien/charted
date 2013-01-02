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
