# frozen_string_literal: true

module Scenic
  module Dependencies
    # Represents a view
    class View
      attr_reader :name

      def initialize(name:, materialized:)
        raise TypeError unless name.is_a?(String)
        raise TypeError unless materialized.is_a?(TrueClass) || materialized.is_a?(FalseClass)

        @name = name
        @materialized = materialized
      end

      def materialized?
        @materialized
      end

      def ==(other)
        name == other.name && materialized? == other.materialized?
      end

      def to_s
        "#{name} (#{materialized? ? 'MV' : 'V'})"
      end

      alias inspect to_s
    end
  end
end
