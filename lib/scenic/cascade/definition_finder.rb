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
          first_path = Scenic::Definition.new(view_name, 1).full_path
          directory = first_path.dirname
          return [] unless directory.directory?

          prefix = first_path.basename.to_s.sub(/\d+\.sql\z/, '')
          directory.children.map { |path| definition_at(path, view_name, prefix) }
                   .compact.sort_by { |definition| definition.version.to_i }
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

        def definition_at(path, view_name, prefix)
          return unless path.file?

          match = /\A#{Regexp.escape(prefix)}(?<version>\d+)\.sql\z/.match(path.basename.to_s)
          return unless match && match[:version].to_i.positive?

          definition = Scenic::Definition.new(view_name, match[:version].to_i)
          definition if definition.full_path == path
        end
      end
    end
  end
end
