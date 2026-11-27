# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

eval_gemfile 'Gemfile.devtools'

if ENV['DRY_TYPES_FROM_MASTER'].eql?('true')
  gem 'dry-types', github: 'dry-rb/dry-types', branch: 'main'
end

# git 'https://github.com/rom-rb/rom.git', branch: 'release-5.4' do
#   gem 'rom'
#   gem 'rom-changeset'
#   gem 'rom-core'
#   gem 'rom-repository'
# end

if ENV['SEQUEL_FROM_MASTER'].eql?('true')
  gem 'sequel', github: 'jeremyevans/sequel', branch: 'master'
else
  gem 'sequel', '5.101.0'
end

group :test do
  gem 'debug', platforms: :ruby

  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.4')
    gem 'mutex_m'
    gem 'ostruct'
  end

  gem 'activesupport', '~> 5.0'
  gem 'dotenv', require: false
  gem 'jdbc-mysql', platforms: :jruby
  gem 'jdbc-postgres', '>= 9.4.1212', platforms: :jruby
  gem 'jdbc-sqlite3', platforms: :jruby
  gem 'mysql2', '~> 0.5', platforms: :ruby
  gem 'pg', '~> 1.2', platforms: :ruby
  gem 'ruby-oci8', platforms: :ruby if ENV['ROM_USE_ORACLE']
  gem 'sequel_pg', require: false, platforms: :ruby
  gem 'sqlite3', '~> 1.4', platforms: :ruby
end
