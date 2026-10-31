# frozen_string_literal: true

require 'generators/scenic/view/view_generator'
require 'scenic/cascade'
require 'scenic/cascade/view_with_version'

module Scenic
  module Generators
    module View
      # Create a database view migration with re-creating of dependent views
      class CascadeGenerator < Scenic::Generators::ViewGenerator
        source_root File.expand_path('templates', __dir__ || '.')

        def create_view_definition
          dependents unless destroying? || creating_new_view?
          super
        end

        def create_migration_file
          if creating_new_view? || destroying_initial_view?
            migration_template('db/migrate/create_view.rb.erb',
                               "db/migrate/create_#{plural_file_name}.rb")
          else
            migration_template('db/migrate/update_view.rb.erb',
                               "db/migrate/update_#{plural_file_name}_to_version_#{version}.rb")
          end
        end

        private

        def dependents
          cached_dependents = @dependents
          return cached_dependents unless cached_dependents.nil?

          view_name = "#{ActiveRecord::Base.table_name_prefix}#{plural_name}#{ActiveRecord::Base.table_name_suffix}"
          deps = Scenic::Cascade.view_dependents_of(view_name, recursive: true)
          views = deps.map { |dep| view_with_version_for(dep) }
          # The last visit follows every prerequisite, even when names sort in the opposite order.
          @dependents = views.reverse.uniq { |view| [view.name, view.version, view.materialized?] }.reverse
        end

        def view_with_version_for(dep)
          name = dep.from.name
          definition = Scenic::Cascade.find_definitions_of(name).last
          raise ArgumentError, "Dependent view #{name} has no Scenic definition file" if definition.nil?

          version = definition.version.to_i
          Scenic::Cascade::ViewWithVersion.new(name: name, version: version, materialized: dep.from.materialized?)
        end
      end
    end
  end
end
