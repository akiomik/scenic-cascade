# frozen_string_literal: true

require_relative 'dependency'

module Scenic
  module Dependencies
    # Finds database views which the specified view depends
    module DependencyFinder
      def self.included(klass)
        klass.extend(ClassMethods)
      end

      # Provides class methods to injected class
      module ClassMethods
        DEPENDENCY_SQL = <<-SQL
             SELECT DISTINCT
                    dependee.relname as to
                  , depender.relname as from
               FROM pg_depend d
               JOIN pg_rewrite r
                 ON d.objid = r.oid
               JOIN pg_class AS dependee
                 ON d.refobjid = dependee.oid
               JOIN pg_class AS depender
                 ON r.ev_class = depender.oid
              WHERE depender.relname = ?
                AND dependee.relname != depender.relname
                AND dependee.relkind in ('m', 'v')
           ORDER BY dependee.relname;
        SQL

        private_constant :DEPENDENCY_SQL

        def view_dependencies_of(view_name, recursive: false)
          query = ActiveRecord::Base.sanitize_sql_array([DEPENDENCY_SQL, view_name])
          raw_dependencies = ActiveRecord::Base.connection.select_all(query).to_a
          dependencies = Scenic::Dependencies::Dependency.from_hash_list(raw_dependencies)

          return [] if dependencies.empty?
          return dependencies unless recursive

          dependencies.flat_map do |dependency|
            [dependency, *view_dependencies_of(dependency.to)]
          end
        end
      end
    end
  end
end
