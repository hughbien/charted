Gem::Specification.new do |s|
  s.name        = 'metrics'
  s.version     = '0.0.1'
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Hugh Bien']
  s.email       = ['hugh@hughbien.com']
  s.homepage    = 'https://github.com/hughbien/metrics'
  s.summary     = 'Minimal web traffic analytics'
  s.description = 'A Sinatra app for tracking web traffic on multiple sites.'
 
  s.required_rubygems_version = '>= 1.3.6'
  s.add_dependency 'sinatra'
  s.add_dependency 'data_mapper'
  s.add_dependency 'pony'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'shotgun'
 
  s.files         = Dir.glob('*.{md,rb,ru}') +
                    %w(metrics) +
                    Dir.glob('{lib,test}/*.rb')
  s.require_paths = ['lib']
  s.bindir        = '.'
  s.executables   = ['metrics']
end
