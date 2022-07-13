# frozen_string_literal: true

require 'scenic/definition'

module Scenic
  # Visualize database view dependencies for Scenic
  module Dependencies
    # Finds view definitions
    module DefinitionFinder
      def self.included(klass)
        klass.extend(ClassMethods)
      end

      # Provides class methods to injected class
      module ClassMethods
        def find_latest_definition_of(view_name)
          definition = go(view_name, 0)
          return definition unless definition.version == '00'

          raise ArgumentError, "View #{view_name} does not exist"
        end

        private

        def go(view_name, version)
          next_definition = Scenic::Definition.new(view_name, version + 1)
          return Scenic::Definition.new(view_name, version) unless File.exist?(next_definition.full_path)

          go(view_name, version + 1)
        end
      end
    end
  end
end
