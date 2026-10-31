# frozen_string_literal: true

require 'rails_helper'

require 'generators/scenic/view/cascade/cascade_generator'

# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe Scenic::Generators::View::CascadeGenerator, size: :medium, type: :generator do
  let(:view_name) { 'search_results' }
  let(:tempdir) { Dir.mktmpdir }

  def create_view_with_definition(name, sql)
    Scenic::Adapters::Postgres.new.create_view(name, sql)
    path = Scenic::Definition.new(name, 1).full_path
    FileUtils.mkpath(File.dirname(path))
    File.write(path, sql)
  end

  def generated_bases_migration
    definition = file('db/views/bases_v02.sql')
    expect(definition).to exist
    File.write(definition, "SELECT 'bar' AS bar")
    load Dir.glob(file('db/migrate/*_update_bases_to_version_2.rb')).fetch(0)
    UpdateBasesToVersion2.new
  end

  def value_of(view)
    ActiveRecord::Base.connection.select_value("SELECT bar FROM #{view}")
  end

  def expect_bases_round_trip(dependent)
    migration = generated_bases_migration
    migration.migrate(:up)
    expect(value_of(dependent)).to eq('bar')
    migration.migrate(:down)
    expect(value_of(dependent)).to eq('foo')
  ensure
    Object.send(:remove_const, :UpdateBasesToVersion2) if Object.const_defined?(:UpdateBasesToVersion2)
  end

  before do
    allow(Rails).to receive(:root).and_return(Pathname.new(tempdir))
    destination tempdir
    prepare_destination
  end

  context 'when creating a new view' do
    let(:migration) { file("db/migrate/create_#{view_name}.rb") }
    let(:view_definition) { file("db/views/#{view_name}_v01.sql") }

    before { run_generator [view_name] }

    it { expect(migration).to be_a_migration }
    it { expect(view_definition).to exist }
  end

  context 'when updating an existing view' do
    let(:migration) { file("db/migrate/update_#{view_name}_to_version_2.rb") }
    let(:view_definition) { file("db/views/#{view_name}_v02.sql") }
    let(:prev_view_definition) { file("db/views/#{view_name}_v01.sql") }

    before do
      FileUtils.mkpath(File.dirname(prev_view_definition))
      FileUtils.touch(prev_view_definition)
      run_generator [view_name]
    end

    it { expect(migration).to be_a_migration }
    it { expect(view_definition).to exist }

    it 'uses update_view by default' do
      expect(migration).to contain_migration(:update_view, ':search_results', version: 2, revert_to_version: 1)
    end
  end

  context 'when replacing an existing view with a dependent' do
    let(:migration) { file('db/migrate/update_bases_to_version_2.rb') }
    let(:migration_sql) { File.read(Dir.glob(file('db/migrate/*_update_bases_to_version_2.rb')).fetch(0)) }

    before do
      create_view_with_definition('bases', "SELECT 'foo' AS bar")
      create_view_with_definition('reports', 'SELECT * FROM bases')
      run_generator ['bases', '--replace']
    end

    it 'uses replace_view for the target' do
      expect(migration).to contain_migration(:replace_view, ':bases', version: 2, revert_to_version: 1)
    end

    it 'still drops and recreates the dependent view' do
      expect(migration_sql).to include('drop_view ExactViewName.new("public.reports")',
                                       'create_view ExactViewName.new("public.reports")')
    end

    it 'applies and reverses the generated migration' do
      expect_bases_round_trip('reports')
    end
  end

  context 'when updating a materialized view side by side' do
    let(:migration) { file('db/migrate/update_bases_to_version_2.rb') }
    let(:migration_sql) { File.read(Dir.glob(file('db/migrate/*_update_bases_to_version_2.rb')).fetch(0)) }

    before do
      Scenic::Adapters::Postgres.new.create_materialized_view('bases', "SELECT 'foo' AS bar")
      FileUtils.mkpath(file('db/views'))
      File.write(file('db/views/bases_v01.sql'), "SELECT 'foo' AS bar")
      create_view_with_definition('reports', 'SELECT * FROM bases')
      run_generator ['bases', '--materialized', '--side-by-side']
    end

    it 'passes the side-by-side option to update_view' do
      expect(migration_sql).to include('materialized: { side_by_side: true }')
    end

    it 'still drops and recreates the dependent view' do
      expect(migration_sql).to include('drop_view ExactViewName.new("public.reports")',
                                       'create_view ExactViewName.new("public.reports")')
    end

    it 'applies and reverses the generated migration' do
      expect_bases_round_trip('reports')
    end
  end

  context 'when updating a materialized view without data' do
    before do
      Scenic::Adapters::Postgres.new.create_materialized_view('bases', "SELECT 'foo' AS bar")
      FileUtils.mkpath(file('db/views'))
      File.write(file('db/views/bases_v01.sql'), "SELECT 'foo' AS bar")
      run_generator ['bases', '--materialized', '--no-data']
    end

    it 'retains the no-data option' do
      migration = Dir.glob(file('db/migrate/*_update_bases_to_version_2.rb')).fetch(0)
      expect(File.read(migration)).to include('materialized: { no_data: true }')
    end
  end

  context 'when update options cannot be honored' do
    before { create_view_with_definition('bases', "SELECT 'foo' AS bar") }

    {
      '--side-by-side' => /requires --materialized/,
      '--materialized --replace' => /--replace cannot update a materialized view/,
      '--materialized --side-by-side --no-data' => /cannot be combined with --no-data/
    }.each do |flags, message|
      it "rejects #{flags}" do
        expect { run_generator ['bases', *flags.split] }.to raise_error(ArgumentError, message)
      end
    end

    it 'does not leave a definition or migration on validation failure' do
      expect do
        run_generator ['bases', '--side-by-side']
      rescue ArgumentError => e
        raise unless e.message.include?('requires --materialized')
      end.not_to(change { Dir.glob(file('db/{views,migrate}/*')) })
    end
  end

  context 'when side-by-side targets a schema-qualified materialized view' do
    before do
      ActiveRecord::Base.connection.execute('CREATE SCHEMA reporting')
      Scenic::Adapters::Postgres.new.create_materialized_view('reporting.bases', "SELECT 'foo' AS bar")
      FileUtils.mkpath(file('db/views'))
      File.write(file('db/views/reporting_bases_v01.sql'), "SELECT 'foo' AS bar")
    end

    it 'rejects the unsupported Scenic update strategy' do
      expect { run_generator ['reporting.bases', '--materialized', '--side-by-side'] }
        .to raise_error(ArgumentError, /cannot update schema-qualified views/)
    end

    it 'leaves existing files untouched' do
      expect do
        run_generator ['reporting.bases', '--materialized', '--side-by-side']
      rescue ArgumentError => e
        raise unless e.message.include?('cannot update schema-qualified views')
      end.not_to(change { Dir.glob(file('db/{views,migrate}/*')) })
    end
  end

  context 'when updating an existing view that is dependent on other views' do
    let(:view_name) { 'firsts' }
    let(:migration) { file("db/migrate/update_#{view_name}_to_version_2.rb") }
    let(:view_definition) { file("db/views/#{view_name}_v02.sql") }
    let(:migration_instance) do
      File.write(view_definition, "SELECT 'bar' AS bar")
      load Dir.glob(file('db/migrate/*_update_firsts_to_version_2.rb')).fetch(0)
      UpdateFirstsToVersion2.new
    end
    let(:view_values) do
      lambda do
        ActiveRecord::Base.connection
                          .select_rows('SELECT firsts.bar, zeta.bar, alpha.bar FROM firsts, zeta, alpha').first
      end
    end

    before do
      adapter = Scenic::Adapters::Postgres.new
      adapter.create_view(
        view_name,
        "SELECT 'foo' AS bar"
      )
      adapter.create_materialized_view(
        'zeta',
        'SELECT * FROM firsts'
      )
      adapter.create_view(
        'alpha',
        'SELECT * FROM firsts UNION SELECT * FROM zeta'
      )

      # Setup firsts
      prev_view_definition = file("db/views/#{view_name}_v01.sql")
      FileUtils.mkpath(File.dirname(prev_view_definition))
      File.write(prev_view_definition, "SELECT 'foo' AS bar")

      # Leave a version gap in zeta's definitions.
      FileUtils.touch(file('db/views/zeta_v01.sql'))
      File.write(file('db/views/zeta_v03.sql'), 'SELECT * FROM firsts')

      # Setup alpha
      FileUtils.touch(file('db/views/alpha_v01.sql'))
      File.write(file('db/views/alpha_v02.sql'), 'SELECT * FROM firsts UNION SELECT * FROM zeta')

      run_generator [view_name]
    end

    after do
      Object.send(:remove_const, :UpdateFirstsToVersion2) if Object.const_defined?(:UpdateFirstsToVersion2)
    end

    it { expect(migration).to be_a_migration }
    it { expect(view_definition).to exist }

    it 'drops alpha before updating firsts' do
      expect(migration).to contain_migration(
        :drop_view, 'ExactViewName.new("public.alpha")', materialized: false
      )
    end

    it 'drops zeta before updating firsts' do
      expect(migration).to contain_migration(
        :drop_view, 'ExactViewName.new("public.zeta")', materialized: true
      )
    end

    it 'recreates zeta from version three across the definition gap' do
      expect(migration).to contain_migration(
        :create_view, 'ExactViewName.new("public.zeta")',
        sql_definition: 'Scenic::Definition.new("zeta", 3).to_sql', materialized: true
      )
    end

    it 'recreates alpha after updating firsts' do
      expect(migration).to contain_migration(
        :create_view, 'ExactViewName.new("public.alpha")',
        sql_definition: 'Scenic::Definition.new("alpha", 2).to_sql', materialized: false
      )
    end

    it 'applies and reverses the generated migration with dependent views' do
      actual = %i[up down].map do |direction|
        migration_instance.migrate(direction)
        view_values.call
      end
      expect(actual).to eq([%w[bar bar bar], %w[foo foo foo]])
    end
  end

  context 'when dependent views form a four-level chain' do
    before do
      create_view_with_definition('bases', "SELECT 'foo' AS bar")
      create_view_with_definition('v_b', 'SELECT * FROM bases')
      create_view_with_definition('v_c', 'SELECT * FROM v_b')
      create_view_with_definition('v_d', 'SELECT * FROM v_c')
      run_generator ['bases']
    end

    it 'updates and restores the deepest dependent view' do
      expect_bases_round_trip('v_d')
    end
  end

  context 'when a dependent view has only a version three definition' do
    let(:migration) { file('db/migrate/update_bases_to_version_2.rb') }

    before do
      create_view_with_definition('bases', "SELECT 'foo' AS bar")
      Scenic::Adapters::Postgres.new.create_view('reports', 'SELECT * FROM bases')
      File.write(file('db/views/reports_v03.sql'), 'SELECT * FROM bases')
      run_generator ['bases']
    end

    it 'recreates the dependent from its existing version three definition' do
      expect(migration).to contain_migration(
        :create_view, 'ExactViewName.new("public.reports")',
        sql_definition: 'Scenic::Definition.new("reports", 3).to_sql', materialized: false
      )
    end

    it 'updates and restores the dependent view' do
      expect_bases_round_trip('reports')
    end
  end

  context 'when an existing database view has no Scenic definition yet' do
    before do
      Scenic::Adapters::Postgres.new.create_view('bases', "SELECT 'foo' AS bar")
      Scenic::Adapters::Postgres.new.create_view('unmanaged', 'SELECT * FROM bases')
      allow(Scenic::Cascade).to receive(:view_dependents_of)
      run_generator ['bases']
    end

    it 'skips the dependency lookup for an initial definition' do
      expect(Scenic::Cascade).not_to have_received(:view_dependents_of)
    end

    it 'creates the initial definition' do
      expect(file('db/views/bases_v01.sql')).to exist
    end

    it 'creates an initial migration' do
      expect(file('db/migrate/create_bases.rb')).to be_a_migration
    end
  end

  context 'when table_name_prefix is configured' do
    let(:migration) { file('db/migrate/update_bases_to_version_2.rb') }

    around do |example|
      original_prefix = ActiveRecord::Base.table_name_prefix
      ActiveRecord::Base.table_name_prefix = 'app_'
      example.run
    ensure
      ActiveRecord::Base.table_name_prefix = original_prefix
    end

    before do
      create_view_with_definition('app_bases', "SELECT 'foo' AS bar")
      create_view_with_definition('app_reports', 'SELECT * FROM app_bases')
      create_view_with_definition('legacy_reports', 'SELECT * FROM app_bases')
      run_generator ['bases']
    end

    it 'drops the prefixed dependent using its database name' do
      expect(migration).to contain_migration(
        :drop_view, 'ExactViewName.new("public.app_reports")', materialized: false
      )
    end

    it 'recreates the unprefixed dependent using its database name' do
      expect(migration).to contain_migration(
        :create_view, 'ExactViewName.new("public.legacy_reports")',
        sql_definition: 'Scenic::Definition.new("legacy_reports", 1).to_sql', materialized: false
      )
    end

    it 'updates and restores the prefixed dependent view' do
      expect_bases_round_trip('app_reports')
    end

    it 'updates and restores the unprefixed dependent view' do
      expect_bases_round_trip('legacy_reports')
    end
  end

  context 'when a schema-qualified view has dependents across schemas' do
    let(:migration) { file('db/migrate/update_reporting_schema_bases_to_version_2.rb') }
    let(:migration_instance) do
      File.write(file('db/views/reporting_schema_bases_v02.sql'), "SELECT 'bar' AS bar")
      load Dir.glob(file('db/migrate/*_update_reporting_schema_bases_to_version_2.rb')).fetch(0)
      UpdateReportingSchemaBasesToVersion2.new
    end
    let(:round_trip_values) do
      %i[up down].map do |direction|
        migration_instance.migrate(direction)
        [value_of('reporting.schema_reports'), value_of('cross_reports'), value_of('schema_reports')]
      end
    end

    before do
      ActiveRecord::Base.connection.execute('CREATE SCHEMA reporting')
      create_view_with_definition('schema_bases', "SELECT 'public' AS bar")
      create_view_with_definition('schema_reports', 'SELECT * FROM schema_bases')
      create_view_with_definition('reporting.schema_bases', "SELECT 'foo' AS bar")
      create_view_with_definition('reporting.schema_reports', 'SELECT * FROM reporting.schema_bases')
      create_view_with_definition('cross_reports', 'SELECT * FROM reporting.schema_reports')
      run_generator ['reporting.schema_bases']
    end

    after do
      if Object.const_defined?(:UpdateReportingSchemaBasesToVersion2)
        Object.send(:remove_const, :UpdateReportingSchemaBasesToVersion2)
      end
    end

    it 'drops the qualified dependent' do
      expect(migration).to contain_migration(
        :drop_view, 'ExactViewName.new("reporting.schema_reports")', revert_to_version: 1, materialized: false
      )
    end

    it 'does not drop an unrelated same-named view' do
      expect(migration).not_to contain_migration(
        :drop_view, 'ExactViewName.new("schema_reports")', revert_to_version: 1, materialized: false
      )
    end

    it 'updates and restores dependents in both schemas' do
      expect(round_trip_values).to eq([%w[bar bar public], %w[foo foo public]])
    end
  end

  context 'when a qualified view name already includes the configured prefix' do
    let(:migration_instance) do
      File.write(file('db/views/reporting_app_bases_v02.sql'), "SELECT 'bar' AS bar")
      load Dir.glob(file('db/migrate/*_update_reporting_app_bases_to_version_2.rb')).fetch(0)
      UpdateReportingAppBasesToVersion2.new
    end

    around do |example|
      original_prefix = ActiveRecord::Base.table_name_prefix
      ActiveRecord::Base.table_name_prefix = 'app_'
      example.run
    ensure
      ActiveRecord::Base.table_name_prefix = original_prefix
    end

    before do
      ActiveRecord::Base.connection.execute('CREATE SCHEMA reporting')
      create_view_with_definition('reporting.app_bases', "SELECT 'foo' AS bar")
      create_view_with_definition('reporting.app_reports', 'SELECT * FROM reporting.app_bases')
      run_generator ['reporting.app_bases']
    end

    after do
      if Object.const_defined?(:UpdateReportingAppBasesToVersion2)
        Object.send(:remove_const, :UpdateReportingAppBasesToVersion2)
      end
    end

    it 'updates and restores the dependent view' do
      migration_instance.migrate(:up)
      updated = value_of('reporting.app_reports')
      migration_instance.migrate(:down)
      expect([updated, value_of('reporting.app_reports')]).to eq(%w[bar foo])
    end
  end

  context 'when a schema-qualified view has no dependents' do
    before do
      ActiveRecord::Base.connection.execute('CREATE SCHEMA reporting')
      create_view_with_definition('reporting.lonely_views', "SELECT 'foo' AS bar")
      run_generator ['reporting.lonely_views']
    end

    it 'keeps the exact target name in the migration' do
      path = Dir.glob(file('db/migrate/*_update_reporting_lonely_views_to_version_2.rb')).fetch(0)
      snippets = ['class ExactViewName < String', 'update_view ExactViewName.new("reporting.lonely_views")']
      expect(File.read(path)).to include(*snippets)
    end
  end

  context 'when search_path resolves an unrelated same-named view first' do
    let(:migration_instance) do
      File.write(file('db/views/public_schema_bases_v02.sql'), "SELECT 'bar' AS bar")
      load Dir.glob(file('db/migrate/*_update_public_schema_bases_to_version_2.rb')).fetch(0)
      UpdatePublicSchemaBasesToVersion2.new
    end
    let(:round_trip_values) do
      migration_instance.migrate(:up)
      updated = [value_of('public.schema_reports'), value_of('public.explicit_reports'),
                 value_of('reporting.schema_reports')]
      migration_instance.migrate(:down)
      restored = [value_of('public.schema_reports'), value_of('public.explicit_reports'),
                  value_of('reporting.schema_reports')]
      [updated, restored]
    end

    before do
      ActiveRecord::Base.connection.execute('CREATE SCHEMA reporting')
      create_view_with_definition('public.schema_bases', "SELECT 'foo' AS bar")
      create_view_with_definition('public.schema_reports', 'SELECT * FROM public.schema_bases')
      create_view_with_definition('public.explicit_reports', 'SELECT * FROM public.schema_bases')
      create_view_with_definition('reporting.schema_bases', "SELECT 'other' AS bar")
      create_view_with_definition('reporting.schema_reports', 'SELECT * FROM reporting.schema_bases')
      ActiveRecord::Base.connection.execute('SET LOCAL search_path TO reporting, public')
      run_generator ['public.schema_bases']
    end

    after do
      if Object.const_defined?(:UpdatePublicSchemaBasesToVersion2)
        Object.send(:remove_const, :UpdatePublicSchemaBasesToVersion2)
      end
    end

    it 'updates public without touching the unrelated reporting view' do
      expect(round_trip_values).to eq([%w[bar bar other], %w[foo foo other]])
    end
  end

  context 'when public dependent definitions have ambiguous file names' do
    before do
      ActiveRecord::Base.connection.execute('CREATE SCHEMA reporting')
      create_view_with_definition('public.schema_bases', "SELECT 'foo' AS bar")
      create_view_with_definition('schema_reports', 'SELECT * FROM public.schema_bases')
      create_view_with_definition('reporting.schema_reports', "SELECT 'other' AS bar")
      File.write(file('db/views/public_schema_reports_v01.sql'), "SELECT 'unrelated' AS bar")
      ActiveRecord::Base.connection.execute('SET LOCAL search_path TO reporting, public')
    end

    it 'explains why the public dependent cannot be resolved' do
      expect { run_generator ['public.schema_bases'] }
        .to raise_error(ArgumentError, /ambiguous Scenic definitions: schema_reports and public\.schema_reports/)
    end

    it 'does not write a definition or migration before rejecting the ambiguity' do
      expect do
        run_generator ['public.schema_bases']
      rescue ArgumentError => e
        raise unless e.message.include?('ambiguous Scenic definitions')
      end.not_to(change { Dir.glob(file('db/{views,migrate}/*')) })
    end
  end

  context 'when a bare definition resolves to another schema first' do
    before do
      ActiveRecord::Base.connection.execute('CREATE SCHEMA reporting')
      create_view_with_definition('public.schema_bases', "SELECT 'foo' AS bar")
      Scenic::Adapters::Postgres.new.create_view('public.schema_reports', 'SELECT * FROM public.schema_bases')
      Scenic::Adapters::Postgres.new.create_view('reporting.schema_reports', "SELECT 'other' AS bar")
      File.write(file('db/views/schema_reports_v01.sql'), "SELECT 'other' AS bar")
      ActiveRecord::Base.connection.execute('SET LOCAL search_path TO reporting, public')
    end

    it 'rejects a bare definition that could belong to the first schema' do
      expect { run_generator ['public.schema_bases'] }
        .to raise_error(ArgumentError, /no unambiguous Scenic definition file/)
    end

    it 'does not write a definition or migration' do
      expect do
        run_generator ['public.schema_bases']
      rescue ArgumentError => e
        raise unless e.message.include?('no unambiguous Scenic definition file')
      end.not_to(change { Dir.glob(file('db/{views,migrate}/*')) })
    end
  end

  context 'when a dependent view has no definition file' do
    before do
      create_view_with_definition('bases', "SELECT 'foo' AS bar")
      Scenic::Adapters::Postgres.new.create_view('unmanaged', 'SELECT * FROM bases')
    end

    it 'explains which dependent view lacks a definition' do
      expect { run_generator ['bases'] }
        .to raise_error(ArgumentError, 'Dependent view unmanaged has no Scenic definition file')
    end

    it 'does not leave an orphan definition or migration' do
      expect do
        run_generator ['bases']
      rescue ArgumentError => e
        raise unless e.message == 'Dependent view unmanaged has no Scenic definition file'
      end.not_to(change { Dir.glob(file('db/{views,migrate}/*')) })
    end

    context 'when the missing definition is added after a failed attempt' do
      before do
        begin
          run_generator ['bases']
        rescue ArgumentError => e
          raise unless e.message == 'Dependent view unmanaged has no Scenic definition file'
        end
        File.write(file('db/views/unmanaged_v01.sql'), 'SELECT * FROM bases')
        generator = described_class.new(['bases'], {}, destination_root: tempdir)
        generator.shell.mute { generator.invoke_all }
      end

      it 'retries at version two with a fresh generator instance' do
        generated = [File.exist?(file('db/views/bases_v02.sql')),
                     File.exist?(file('db/views/bases_v03.sql')),
                     Dir.glob(file('db/migrate/*_update_bases_to_version_2.rb')).size]
        expect(generated).to eq([true, false, 1])
      end

      it 'reverts to the version before the failed attempt' do
        expect(file('db/migrate/update_bases_to_version_2.rb'))
          .to contain_migration(:update_view, ':bases', version: 2, revert_to_version: 1)
      end
    end
  end

  context 'when migration generation fails after writing a definition' do
    let(:existing_migration) { file('db/migrate/20260101000000_update_bases_to_version_2.rb') }

    before do
      create_view_with_definition('bases', "SELECT 'foo' AS bar")
      FileUtils.mkpath(File.dirname(existing_migration))
      File.write(existing_migration, '# existing migration')
    end

    context 'when the migration name collides' do
      let(:collision_error) do
        run_generator ['bases']
      rescue Rails::Generators::Error => e
        e
      end

      it 'reports the collision' do
        expect(collision_error.message).to include('Another migration is already named')
      end

      it 'preserves the existing migration' do
        collision_error
        expect(File.read(existing_migration)).to eq('# existing migration')
      end

      it 'removes the new definition' do
        collision_error
        expect(file('db/views/bases_v02.sql')).not_to exist
      end

      it 'does not leave another migration' do
        collision_error
        expect(Dir.glob(file('db/migrate/*_update_bases_to_version_2.rb'))).to eq([existing_migration])
      end
    end

    context 'when retried after resolving the migration collision' do
      before do
        begin
          run_generator ['bases']
        rescue Rails::Generators::Error => e
          raise unless e.message.include?('Another migration is already named')
        end
        File.delete(existing_migration)
        generator = described_class.new(['bases'], {}, destination_root: tempdir)
        generator.shell.mute { generator.invoke_all }
      end

      it 'uses version two again' do
        expect([file('db/views/bases_v02.sql'), file('db/views/bases_v03.sql')].map { |path| File.exist?(path) })
          .to eq([true, false])
      end

      it 'reverts to version one' do
        expect(file('db/migrate/update_bases_to_version_2.rb'))
          .to contain_migration(:update_view, ':bases', version: 2, revert_to_version: 1)
      end
    end

    context 'when template rendering leaves a partial migration' do
      let(:template_error) do
        generator = described_class.new(['bases'], {}, destination_root: tempdir)
        allow(generator).to receive(:migration_template) do
          File.write(existing_migration, '# overwritten migration')
          File.write(file('db/migrate/20260101000001_update_bases_to_version_2.rb'), '# partial migration')
          raise IOError, 'template failed'
        end
        generator.shell.mute { generator.invoke_all }
      rescue IOError => e
        e
      end

      it 'reports the template failure' do
        expect(template_error.message).to eq('template failed')
      end

      it 'removes the new definition' do
        template_error
        expect(file('db/views/bases_v02.sql')).not_to exist
      end

      it 'removes only the partial migration' do
        template_error
        expect(Dir.glob(file('db/migrate/*_update_bases_to_version_2.rb'))).to eq([existing_migration])
      end

      it 'preserves the existing migration content' do
        template_error
        expect(File.read(existing_migration)).to eq('# existing migration')
      end
    end
  end

  context 'when an existing migration is skipped' do
    let(:existing_migration) { file('db/migrate/20260101000000_update_bases_to_version_2.rb') }

    before do
      create_view_with_definition('bases', "SELECT 'foo' AS bar")
      FileUtils.mkpath(File.dirname(existing_migration))
      File.write(existing_migration, '# existing migration')
      generator = described_class.new(['bases'], { skip: true }, destination_root: tempdir)
      generator.shell.mute { generator.invoke_all }
    end

    it 'does not leave a new definition' do
      expect(file('db/views/bases_v02.sql')).not_to exist
    end

    it 'preserves the existing migration' do
      expect(File.read(existing_migration)).to eq('# existing migration')
    end

    it 'does not create another migration' do
      expect(Dir.glob(file('db/migrate/*_update_bases_to_version_2.rb'))).to eq([existing_migration])
    end

    context 'when retried after the collision is removed' do
      before do
        File.delete(existing_migration)
        generator = described_class.new(['bases'], {}, destination_root: tempdir)
        generator.shell.mute { generator.invoke_all }
      end

      it 'uses version two' do
        expect([file('db/views/bases_v02.sql'), file('db/views/bases_v03.sql')].map { |path| File.exist?(path) })
          .to eq([true, false])
      end

      it 'reverts to version one' do
        expect(file('db/migrate/update_bases_to_version_2.rb'))
          .to contain_migration(:update_view, ':bases', version: 2, revert_to_version: 1)
      end
    end
  end

  context 'when skip is requested without a migration collision' do
    before do
      create_view_with_definition('bases', "SELECT 'foo' AS bar")
      generator = described_class.new(['bases'], { skip: true }, destination_root: tempdir)
      generator.shell.mute { generator.invoke_all }
    end

    it 'creates the next definition' do
      expect(file('db/views/bases_v02.sql')).to exist
    end

    it 'creates a matching migration' do
      expect(file('db/migrate/update_bases_to_version_2.rb'))
        .to contain_migration(:update_view, ':bases', version: 2, revert_to_version: 1)
    end
  end

  context 'when an identical migration already exists but its definition is missing' do
    before do
      create_view_with_definition('bases', "SELECT 'foo' AS bar")
      original = described_class.new(['bases'], {}, destination_root: tempdir)
      original.shell.mute { original.invoke_all }
      File.delete(file('db/views/bases_v02.sql'))
      File.write(file('db/migrate/!_update_bases_to_version_2.rb'), '# unrelated file')
      retry_generator = described_class.new(['bases'], { skip: true }, destination_root: tempdir)
      retry_generator.shell.mute { retry_generator.invoke_all }
    end

    it 'restores the definition referenced by the existing migration' do
      expect(file('db/views/bases_v02.sql')).to exist
    end

    it 'retains the existing migration' do
      expect(Dir.glob(file('db/migrate/[0-9]*_update_bases_to_version_2.rb')).size).to eq(1)
    end

    it 'preserves the unrelated file' do
      expect(File.read(file('db/migrate/!_update_bases_to_version_2.rb'))).to eq('# unrelated file')
    end
  end

  context 'when revoking an update and migration generation fails' do
    let(:definition) { file('db/views/bases_v02.sql') }

    before do
      create_view_with_definition('bases', "SELECT 'foo' AS bar")
      File.write(definition, "SELECT 'bar' AS bar")
      generator = described_class.new(['bases'], {}, destination_root: tempdir)
      generator.behavior = :revoke
      allow(generator).to receive(:migration_template).and_raise(IOError, 'template failed')
      generator.shell.mute { generator.invoke_all }
    rescue IOError => e
      raise unless e.message == 'template failed'
    end

    it 'restores the preexisting definition' do
      expect(File.read(definition)).to eq("SELECT 'bar' AS bar")
    end
  end

  context 'when destroying an update with an unmanaged dependent' do
    let(:migration) { file('db/migrate/20260101000000_update_bases_to_version_2.rb') }

    before do
      create_view_with_definition('bases', "SELECT 'foo' AS bar")
      Scenic::Adapters::Postgres.new.create_view('unmanaged', 'SELECT * FROM bases')
      File.write(file('db/views/bases_v02.sql'), "SELECT 'bar' AS bar")
      FileUtils.mkpath(File.dirname(migration))
      File.write(migration, '# generated migration')
      run_generator ['bases'], behavior: :revoke
    end

    it 'removes the version two definition' do
      expect(file('db/views/bases_v02.sql')).not_to exist
    end

    it 'removes the version two migration' do
      expect(migration).not_to exist
    end
  end

  context 'when a dependent definition has a noncanonical filename' do
    before do
      create_view_with_definition('bases', "SELECT 'foo' AS bar")
      Scenic::Adapters::Postgres.new.create_view('unmanaged', 'SELECT * FROM bases')
      File.write(file('db/views/unmanaged_v3.sql'), 'SELECT * FROM bases')
    end

    it 'reports the invalid filename' do
      expect { run_generator ['bases'] }.to raise_error(ArgumentError, /Noncanonical view definition/)
    end

    it 'does not leave an orphan definition or migration' do
      expect do
        run_generator ['bases']
      rescue ArgumentError => e
        raise unless e.message.include?('Noncanonical view definition')
      end.not_to(change { Dir.glob(file('db/{views,migrate}/*')) })
    end
  end

  context 'when dependency paths converge' do
    before do
      create_view_with_definition('bases', "SELECT 'foo' AS bar")
      create_view_with_definition('v_q', 'SELECT * FROM bases')
      create_view_with_definition('v_r', 'SELECT * FROM v_q')
      create_view_with_definition('v_p', 'SELECT * FROM bases UNION SELECT * FROM v_r')
      run_generator ['bases']
    end

    it 'updates and restores the shared dependent view' do
      expect_bases_round_trip('v_p')
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
