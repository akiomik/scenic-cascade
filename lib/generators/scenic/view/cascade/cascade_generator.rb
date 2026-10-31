# frozen_string_literal: true

require 'erb'
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
          @definition_path = @original_definition = nil
          validate_update_options! unless destroying? || creating_new_view?
          dependents unless destroying? || creating_new_view?
          path = Scenic::Definition.new(plural_file_name, version).full_path.to_s
          @definition_path = path
          @original_definition = File.binread(path) if File.file?(path)
          super
        rescue StandardError
          restore_definition
          raise
        end

        def create_migration_file
          template, destination = migration_template_details
          pattern = File.join(destination_root, 'db/migrate', "[0-9]*_#{File.basename(destination)}")
          original_migrations = Dir.glob(pattern).to_h { |path| [path, File.binread(path)] }
          migration_template(template, destination)
          # Thor returns normally for --skip even though it did not create a migration.
          restore_definition if options[:skip] && skipped_migration?(template, pattern, original_migrations)
        rescue StandardError
          restore_migrations(pattern, original_migrations) if pattern && original_migrations
          restore_definition
          raise
        end

        private

        def validate_update_options!
          raise ArgumentError, '--replace cannot update a materialized view' if options[:replace] && materialized?

          validate_side_by_side_option! if options[:side_by_side]
        end

        def validate_side_by_side_option!
          raise ArgumentError, '--side-by-side requires --materialized' unless materialized?
          raise ArgumentError, '--side-by-side cannot update schema-qualified views' if plural_name.include?('.')

          raise ArgumentError, '--side-by-side cannot be combined with --no-data' if options[:no_data]
        end

        def migration_template_details
          return ['db/migrate/create_view.rb.erb', "db/migrate/create_#{plural_file_name}.rb"] if
            creating_new_view? || destroying_initial_view?

          ['db/migrate/update_view.rb.erb', "db/migrate/update_#{plural_file_name}_to_version_#{version}.rb"]
        end

        def restore_definition
          return unless (path = @definition_path)

          if (original = @original_definition)
            restore_file(path, original)
          elsif File.file?(path)
            File.delete(path)
          end
        end

        def restore_migrations(pattern, originals)
          (Dir.glob(pattern) - originals.keys).each { |path| File.delete(path) }
          originals.each { |path, content| restore_file(path, content) }
        end

        def restore_file(path, content)
          File.binwrite(path, content) unless File.file?(path) && File.binread(path) == content
        end

        def skipped_migration?(template, pattern, originals)
          return false unless Dir.glob(pattern).to_h { |path| [path, File.binread(path)] } == originals

          originals.values.first != ERB.new(File.read(find_in_source_paths(template)), trim_mode: '-').result(binding).b
        end

        def dependents
          cached_dependents = @dependents
          return cached_dependents unless cached_dependents.nil?

          deps = Scenic::Cascade.view_dependents_of(database_view_name, recursive: true)
          views = deps.map { |dep| view_with_version_for(dep) }
          # The last visit follows every prerequisite, even when names sort in the opposite order.
          @dependents = views.reverse.uniq { |view| [view.name, view.version, view.materialized?] }.reverse
        end

        def view_with_version_for(dep)
          name = dep.from.name
          definition_name = definition_name_for(name)
          definition = Scenic::Cascade.find_definitions_of(definition_name).last
          raise ArgumentError, "Dependent view #{name} has no Scenic definition file" if definition.nil?

          Scenic::Cascade::ViewWithVersion.new(
            name: definition_name, version: definition.version.to_i,
            materialized: dep.from.materialized?, database_name: qualified_name(name)
          )
        end

        def definition_name_for(name)
          return name if name.include?('.')

          qualified = qualified_name(name)
          qualified_definitions = Scenic::Cascade.find_definitions_of(qualified)
          bare_definitions = Scenic::Cascade.find_definitions_of(name)

          if qualified_definitions.any? && bare_definitions.any?
            raise ArgumentError, "Dependent view #{name} has ambiguous Scenic definitions: #{name} and #{qualified}"
          end

          return qualified if qualified_definitions.any?
          return name if bare_definitions.empty? || bare_name_resolves_to_public?(name)

          raise ArgumentError, "Dependent view #{name} has no unambiguous Scenic definition file for #{qualified}"
        end

        def bare_name_resolves_to_public?(name)
          connection = ActiveRecord::Base.connection
          bare = connection.quote(connection.quote_table_name(name))
          qualified = connection.quote(connection.quote_table_name(qualified_name(name)))
          connection.select_value("SELECT to_regclass(#{bare}) = to_regclass(#{qualified})")
        end

        def qualified_name(name)
          name.include?('.') ? name : "public.#{name}"
        end

        def database_view_name
          return plural_name if plural_name.include?('.')

          "#{ActiveRecord::Base.table_name_prefix}#{plural_name}#{ActiveRecord::Base.table_name_suffix}"
        end
      end
    end
  end
end
