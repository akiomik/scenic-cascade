# frozen_string_literal: true

require 'active_record'
require 'database_cleaner/active_record'
require 'scenic'
require 'simplecov'
require 'simplecov-cobertura'

SimpleCov.start 'rails'
SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter

require 'scenic/cascade'

Dir['./spec/support/**/*.rb'].sort.each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:all, size: ->(size) { size != :small }) do
    ActiveRecord::Base.establish_connection(
      adapter: 'postgresql',
      host: ENV.fetch('POSTGRES_HOST'),
      username: ENV.fetch('POSTGRES_USER'),
      password: ENV.fetch('POSTGRES_PASSWORD'),
      database: ENV.fetch('POSTGRES_DB')
    )

    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:example, size: ->(size) { size != :small }) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
