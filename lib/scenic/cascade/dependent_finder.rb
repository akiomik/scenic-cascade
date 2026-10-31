# frozen_string_literal: true

require_relative 'dependency'

module Scenic
  module Cascade
    # Finds database views that depend on the specified view
    module DependentFinder
      def self.included(klass)
        klass.extend(ClassMethods)
      end

      # Provides class methods to injected class
      module ClassMethods
        DEPENDANT_SQL = <<-SQL
             SELECT DISTINCT
                    CASE WHEN dependee_ns.nspname = 'public' THEN dependee.relname
                         ELSE dependee_ns.nspname || '.' || dependee.relname END AS to
                  , dependee.relkind = 'm' AS to_materialized
                  , CASE WHEN depender_ns.nspname = 'public' THEN depender.relname
                         ELSE depender_ns.nspname || '.' || depender.relname END AS from
                  , depender.relkind = 'm' AS from_materialized
                  , format('%I.%I', depender_ns.nspname, depender.relname) AS from_lookup
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
              WHERE dependee.oid = to_regclass(?)
                AND depender.oid != dependee.oid
                AND depender.relkind in ('m', 'v')
           ORDER BY from_lookup;
        SQL

        private_constant :DEPENDANT_SQL

        def view_dependents_of(view_name, recursive: false)
          query = ActiveRecord::Base.sanitize_sql_array([DEPENDANT_SQL, view_name])
          raw_dependencies = ActiveRecord::Base.connection.select_all(query).to_a
          dependencies = raw_dependencies.map { |dep| Scenic::Cascade::Dependency.from_hash(dep) }

          return [] if dependencies.empty?
          return dependencies unless recursive

          raw_dependencies.zip(dependencies).flat_map do |row, dependency|
            [dependency, *view_dependents_of(row.fetch('from_lookup'), recursive: true)]
          end
        end

        alias view_dependants_of view_dependents_of
      end
    end
  end
end
