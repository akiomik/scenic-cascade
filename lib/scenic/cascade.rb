# frozen_string_literal: true

require 'active_record'
require 'scenic'

require_relative 'cascade/version'
require_relative 'cascade/definition_finder'
require_relative 'cascade/dependency_finder'
require_relative 'cascade/dependent_finder'

module Scenic
  # Manage database view dependencies for Scenic
  module Cascade
    include Scenic::Cascade::DefinitionFinder
    include Scenic::Cascade::DependencyFinder
    include Scenic::Cascade::DependentFinder
  end
end
