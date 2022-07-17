# frozen_string_literal: true

require 'scenic/dependencies/view'

module Scenic
  module Dependencies
    # Represents a view dependency
    class Dependency
      attr_reader :from, :to

      def initialize(from:, to:)
        raise TypeError unless from.is_a?(Scenic::Dependencies::View)
        raise TypeError unless to.is_a?(Scenic::Dependencies::View)

        @from = from
        @to = to
      end

      def ==(other)
        from == other.from && to == other.to
      end

      # mermaid-like syntax
      def to_s
        "#{from.name}[#{from}] --> #{to.name}[#{to}]"
      end

      alias inspect to_s

      def self.from_hash(hash)
        from = Scenic::Dependencies::View.new(name: hash['from'], materialized: hash['from_materialized'])
        to = Scenic::Dependencies::View.new(name: hash['to'], materialized: hash['to_materialized'])
        new(from: from, to: to)
      end
    end
  end
end
