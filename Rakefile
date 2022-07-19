# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)
RSpec::Core::RakeTask.new('spec:small') do |task|
  task.rspec_opts = '--tag size:small'
end

require 'rubocop/rake_task'

RuboCop::RakeTask.new

desc 'Run `bundle exec steep check`'
task 'steep:check' do
  sh 'bundle exec steep check'
end

task steep: ['steep:check']

task default: %i[spec rubocop steep:check]
