# frozen_string_literal: true

require 'scenic/definition'

module Scenic
  # Visualize database view dependencies for Scenic
  module Cascade
    # Finds view definitions
    module DefinitionFinder
      def self.included(klass)
        klass.extend(ClassMethods)
      end

      # Provides class methods to injected class
      module ClassMethods
        def find_definitions_of(view_name)
          go(view_name, 1)
        end

        def find_latest_definition_of(view_name)
          latest_definition = find_definitions_of(view_name).last
          unless latest_definition.nil?
            # @type var latest_definition: Scenic::Definition
            return latest_definition
          end

          raise ArgumentError, "View #{view_name} does not exist"
        end

        private

        def go(view_name, version)
          definition = Scenic::Definition.new(view_name, version)
          return [] unless File.exist?(definition.full_path)

          [definition, *go(view_name, version + 1)]
        end
      end
    end
  end
end
