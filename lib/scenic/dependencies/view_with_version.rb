# frozen_string_literal: true

module Scenic
  module Dependencies
    # Represents a view with version
    class ViewWithVersion < Scenic::Dependencies::View
      attr_reader :version

      def initialize(name:, version:, materialized:)
        super(name: name, materialized: materialized)

        raise TypeError unless version.is_a?(Integer)

        @version = version
      end

      def ==(other)
        name == other.name && version == other.version && materialized? == other.materialized?
      end

      def to_s
        "#{name}_v#{formatted_version} (#{materialized? ? 'MV' : 'V'})"
      end

      alias inspect to_s

      private

      def formatted_version
        version.to_s.rjust(2, '0')
      end
    end
  end
end
