# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in scenic-cascade.gemspec
gemspec

gem 'rake', '~> 13.0'

# type checking
# Steep 2.x drops Ruby 3.1, which remains in the CI matrix.
gem 'steep', '~> 1.10', require: false

# testing
gem 'activerecord', '~> 7.1.0'
gem 'ammeter', '~> 1.1'
gem 'database_cleaner-active_record', '~> 2.0'
# Nokogiri 1.19 drops Ruby 3.1, which remains in the CI matrix.
gem 'nokogiri', '~> 1.18.0'
gem 'pg', '~> 1.0'
gem 'railties', '~> 7.1.0'
gem 'rspec', '~> 3.0'
gem 'simplecov', require: false
gem 'simplecov-cobertura', '~> 3.2', require: false

# linting
gem 'rubocop', '~> 1.21', require: false
gem 'rubocop-performance', '~> 1.14', require: false
gem 'rubocop-rake', '~> 0.6', require: false
gem 'rubocop-rspec', '~> 2.12', require: false
