# frozen_string_literal: true

module Scenic
  module Dependencies
    # Represents a view dependency
    class Dependency
      attr_reader :from, :to

      def initialize(from:, to:)
        raise TypeError if from.nil? || to.nil?

        @from = from
        @to = to
      end

      def ==(other)
        @from == other.from && @to == other.to
      end

      # mermaid-like syntax
      def to_s
        "#{@from} --> #{@to}"
      end

      alias inspect to_s

      def self.from_hash_list(hash_list)
        hash_list.map { |h| new(from: h['from'], to: h['to']) }
      end
    end
  end
end
