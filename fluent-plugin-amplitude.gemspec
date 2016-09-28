# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'fluent-plugin-amplitude'
  spec.version       = '0.0.1'
  spec.authors       = ['Vijay Ramesh']
  spec.email         = ['vijay@change.org']
  spec.summary       = 'Fluentd plugin to output event data to Amplitude'
  spec.description   = 'Fluentd plugin to output event data to Amplitude'
  spec.homepage      = 'https://github.com/change/fluent-plugin-amplitude'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'fluentd', '>= 0.10.55'
  spec.add_runtime_dependency 'amplitude-api', '~> 0.0.9'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'test-unit'
  spec.add_development_dependency 'rspec-mocks'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'msgpack'
end
