require_relative 'lib/charted/version'

Gem::Specification.new do |s|
  s.name        = 'charted'
  s.version     = Charted::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Hugh Bien']
  s.email       = ['hugh@hughbien.com']
  s.homepage    = 'https://github.com/hughbien/charted'
  s.summary     = 'Minimal web traffic analytics'
  s.description = 'A Sinatra app for tracking web traffic on multiple sites.'
 
  s.required_rubygems_version = '>= 1.3.6'
  s.add_dependency 'sinatra'
  s.add_dependency 'data_mapper'
  s.add_dependency 'geoip'
  s.add_dependency 'pony'
  s.add_dependency 'useragent'
  s.add_dependency 'search_terms'
  s.add_dependency 'dashes'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'rack-test'
  s.add_development_dependency 'dm-sqlite-adapter'
 
  s.files         = Dir.glob('*.{md,rb,ru,dat}') +
                    %w(public/charted/script.js) +
                    Dir.glob('{bin,lib,test}/**/*.rb')
  s.require_paths = ['lib']
  s.bindir        = 'bin'
  s.executables   = ['charted']
end
