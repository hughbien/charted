Gem::Specification.new do |s|
  s.name        = 'charted'
  s.version     = '0.0.5'
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
  s.add_dependency 'colorize'
  s.add_dependency 'dashes'
  s.add_development_dependency 'minitest'
 
  s.files         = Dir.glob('*.{md,rb,ru,dat}') +
                    %w(charted) +
                    Dir.glob('{lib,test}/*.rb')
  s.require_paths = ['lib']
  s.bindir        = '.'
  s.executables   = ['charted']
end
