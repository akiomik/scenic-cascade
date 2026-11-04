# frozen_string_literal: true

appraise 'rails-7-1' do
  gem 'activerecord', '~> 7.1.0'
  gem 'railties', '~> 7.1.0'
end

appraise 'rails-8-0' do
  gem 'activerecord', '>= 8.0.5.2', '< 8.1'
  # Keep the root bundle compatible with Ruby 3.1; the patched Rails 8 stack needs newer Nokogiri.
  gem 'nokogiri', '~> 1.19.5'
  gem 'railties', '>= 8.0.5.2', '< 8.1'
end
