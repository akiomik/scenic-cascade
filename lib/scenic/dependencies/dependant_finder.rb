# frozen_string_literal: true

module Scenic
  module Dependencies
    # Finds database views that depend on the specified view
    module DependantFinder
      def self.included(klass)
        klass.extend(ClassMethods)
      end

      # Class methods of DependantFinder
      module ClassMethods
        DEPENDANT_SQL = <<-SQL
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
              WHERE dependee.relname = ?
                AND depender.relname != dependee.relname
                AND depender.relkind in ('m', 'v')
           ORDER BY depender.relname;
        SQL

        private_constant :DEPENDANT_SQL

        def view_dependants_of(view_name, recursive: false)
          query = ActiveRecord::Base.sanitize_sql_array([DEPENDANT_SQL, view_name])
          dependencies = ActiveRecord::Base.connection.select_all(query).to_a

          return [] if dependencies.empty?
          return dependencies unless recursive

          dependencies.flat_map do |dependency|
            [dependency, *view_dependants_of(dependency['from'])]
          end
        end

        alias view_dependents_of view_dependants_of
      end
    end
  end
end
