# frozen_string_literal: true

require 'active_record'
require 'scenic'

require_relative 'dependencies/version'
require_relative 'dependencies/dependant_finder'
require_relative 'dependencies/dependency_finder'

module Scenic
  # Visualize database view dependencies for Scenic
  module Dependencies
    include Scenic::Dependencies::DependantFinder
    include Scenic::Dependencies::DependencyFinder
  end
end
