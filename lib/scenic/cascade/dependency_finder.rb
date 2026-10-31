# frozen_string_literal: true

require_relative 'dependency'

module Scenic
  module Cascade
    # Finds database views which the specified view depends
    module DependencyFinder
      def self.included(klass)
        klass.extend(ClassMethods)
      end

      # Provides class methods to injected class
      module ClassMethods
        DEPENDENCY_SQL = <<-SQL
             SELECT DISTINCT
                    CASE WHEN dependee_ns.nspname = 'public' THEN dependee.relname
                         ELSE dependee_ns.nspname || '.' || dependee.relname END AS to
                  , dependee.relkind = 'm' AS to_materialized
                  , CASE WHEN depender_ns.nspname = 'public' THEN depender.relname
                         ELSE depender_ns.nspname || '.' || depender.relname END AS from
                  , depender.relkind = 'm' AS from_materialized
                  , format('%I.%I', dependee_ns.nspname, dependee.relname) AS to_lookup
               FROM pg_depend d
               JOIN pg_rewrite r
                 ON d.objid = r.oid
               JOIN pg_class AS dependee
                 ON d.refobjid = dependee.oid
               JOIN pg_namespace AS dependee_ns
                 ON dependee.relnamespace = dependee_ns.oid
               JOIN pg_class AS depender
                 ON r.ev_class = depender.oid
               JOIN pg_namespace AS depender_ns
                 ON depender.relnamespace = depender_ns.oid
              WHERE depender.oid = to_regclass(?)
                AND dependee.oid != depender.oid
                AND dependee.relkind in ('m', 'v')
           ORDER BY to_lookup;
        SQL

        private_constant :DEPENDENCY_SQL

        def view_dependencies_of(view_name, recursive: false)
          query = ActiveRecord::Base.sanitize_sql_array([DEPENDENCY_SQL, view_name])
          raw_dependencies = ActiveRecord::Base.connection.select_all(query).to_a
          dependencies = raw_dependencies.map { |dep| Scenic::Cascade::Dependency.from_hash(dep) }

          return [] if dependencies.empty?
          return dependencies unless recursive

          raw_dependencies.zip(dependencies).flat_map do |row, dependency|
            [dependency, *view_dependencies_of(row.fetch('to_lookup'), recursive: true)]
          end
        end
      end
    end
  end
end
