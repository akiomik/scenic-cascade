# frozen_string_literal: true

require_relative 'view'

module Scenic
  module Cascade
    # Represents a view with version
    class ViewWithVersion < Scenic::Cascade::View
      attr_reader :version, :database_name

      def initialize(name:, version:, materialized:, database_name: name)
        super(name: name, materialized: materialized)

        raise TypeError unless version.is_a?(Integer)
        raise TypeError unless database_name.is_a?(String)

        @version = version
        @database_name = database_name
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
