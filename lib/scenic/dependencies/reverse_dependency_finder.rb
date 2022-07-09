# frozen_string_literal: true

module Scenic
  module Dependencies
    # Finds reverse dependencies of database views
    module ReverseDependencyFinder
      def self.included(klass)
        klass.extend(ClassMethods)
      end

      # Class methods of ReverseDependencyFinder
      module ClassMethods
        REVERSE_DEPENDENCY_SQL = <<-SQL
             SELECT DISTINCT
                    dependee.relname as dependee
                  , depender.relname as depender
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

        private_constant :REVERSE_DEPENDENCY_SQL

        def reverse_dependent_views_of(view_name, recursive: false)
          query = ActiveRecord::Base.sanitize_sql_array([REVERSE_DEPENDENCY_SQL, view_name])
          dependencies = ActiveRecord::Base.connection.select_all(query).to_a

          return [] if dependencies.empty?
          return dependencies unless recursive

          dependencies.flat_map do |dependency|
            [dependency, *reverse_dependent_views_of(dependency['depender'])]
          end
        end
      end
    end
  end
end
