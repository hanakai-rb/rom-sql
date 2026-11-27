lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rom/sql/version'

Gem::Specification.new do |spec|
  spec.name          = 'rom-sql'
  spec.version       = ROM::SQL::VERSION.dup
  spec.authors       = ['Piotr Solnica']
  spec.email         = ['piotr.solnica@gmail.com']
  spec.summary       = 'SQL databases support for ROM'
  spec.description   = spec.summary
  spec.homepage      = 'http://rom-rb.org'
  spec.license       = 'MIT'
  spec.metadata      = {
    'source_code_uri'   => 'https://github.com/rom-rb/rom-sql',
    'documentation_uri' => 'https://api.rom-rb.org/rom-sql/',
    'mailing_list_uri'  => 'https://discourse.rom-rb.org/',
    'bug_tracker_uri'   => 'https://github.com/rom-rb/rom-sql/issues',
  }

  spec.files         = Dir['CHANGELOG.md', 'LICENSE', 'README.md', 'lib/**/*']
  spec.require_paths = ['lib']

  spec.required_ruby_version = ">= 3.3"

  spec.add_runtime_dependency 'sequel', '>= 4.49'
  spec.add_runtime_dependency 'dry-types', '~> 1.8'
  spec.add_runtime_dependency 'dry-core', '~> 1.1'
  spec.add_runtime_dependency 'rom', '~> 5.4'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.9'
end
