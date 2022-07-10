# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)
RSpec::Core::RakeTask.new(:spec_small) do |task|
  task.rspec_opts = '--tag size:small'
end

require 'rubocop/rake_task'

RuboCop::RakeTask.new

task default: %i[spec rubocop]
