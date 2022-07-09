# frozen_string_literal: true

require 'active_record'
require 'scenic'

require_relative 'dependencies/version'
require_relative 'dependencies/dependant_finder'

module Scenic
  # Visualize database view dependencies for Scenic
  module Dependencies
    include Scenic::Dependencies::DependantFinder
  end
end
