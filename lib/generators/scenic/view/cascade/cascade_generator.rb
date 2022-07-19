# frozen_string_literal: true

require 'generators/scenic/view/view_generator'

module Scenic
  module Generators
    module View
      # Create a database view migration with re-creating of dependent views
      class CascadeGenerator < Scenic::Generators::ViewGenerator
        source_root File.expand_path('templates', __dir__ || '.')

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
          return @dependents if @dependents.present?

          deps = Scenic::Dependencies.view_dependents_of(plural_name, recursive: true)
          @dependents ||= deps.map do |dep|
            name = dep.from.name
            version = Scenic::Dependencies.find_latest_definition_of(name).version.to_i
            is_materialized = dep.from.materialized?
            Scenic::Dependencies::ViewWithVersion.new(name: name, version: version, materialized: is_materialized)
          end.uniq
        end
      end
    end
  end
end
