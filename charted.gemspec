require_relative 'lib/charted/version'

Gem::Specification.new do |s|
  s.name        = 'charted'
  s.version     = Charted::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Hugh Bien']
  s.email       = ['hugh@hughbien.com']
  s.licenses    = ['BSD']
  s.homepage    = 'https://github.com/hughbien/charted'
  s.summary     = 'Minimal web traffic analytics'
  s.description = 'A Sinatra app for tracking web traffic on multiple sites.'
 
  s.required_ruby_version = '~> 2.0'
  s.add_dependency 'sinatra', '~> 1.4'
  s.add_dependency 'sequel', '~> 4.12'
  s.add_dependency 'geoip', '~> 1.4'
  s.add_dependency 'pony', '~> 1.10'
  s.add_dependency 'useragent', '~> 0.10'
  s.add_dependency 'search_terms', '~> 0.0'
  s.add_dependency 'dashes', '~> 0.0'
  s.add_development_dependency 'minitest', '~> 5.4'
  s.add_development_dependency 'rack-test', '~> 0.6'
  s.add_development_dependency 'sqlite3', '~> 1.3'
 
  s.files         = Dir.glob('*.{md,rb,ru,dat}') +
                    %w(public/charted/script.js) +
                    Dir.glob('{bin,lib,migrate,test}/**/*.rb')
  s.require_paths = ['lib']
  s.bindir        = 'bin'
  s.executables   = ['charted']
end
