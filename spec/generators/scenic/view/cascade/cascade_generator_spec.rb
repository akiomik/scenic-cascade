# frozen_string_literal: true

require 'rails_helper'

require 'generators/scenic/view/cascade/cascade_generator'

# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe Scenic::Generators::View::CascadeGenerator, size: :medium, type: :generator do
  let(:view_name) { 'search_results' }
  let(:tempdir) { Dir.mktmpdir }

  def create_view_with_definition(name, sql)
    Scenic::Adapters::Postgres.new.create_view(name, sql)
    path = file("db/views/#{name}_v01.sql")
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
    it { expect(migration).to contain_migration(:drop_view, ':alpha', revert_to_version: 2, materialized: false) }
    it { expect(migration).to contain_migration(:drop_view, ':zeta', revert_to_version: 3, materialized: true) }

    it 'recreates zeta from version three across the definition gap' do
      expect(migration).to contain_migration(:create_view, ':zeta', version: 3, materialized: true)
    end

    it { expect(migration).to contain_migration(:create_view, ':alpha', version: 2, materialized: false) }

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

  context 'when a dependent view has no definition file' do
    before do
      create_view_with_definition('bases', "SELECT 'foo' AS bar")
      Scenic::Adapters::Postgres.new.create_view('unmanaged', 'SELECT * FROM bases')
    end

    it 'explains which dependent view lacks a definition' do
      expect { run_generator ['bases'] }.to raise_error(ArgumentError, 'View unmanaged does not exist')
    end

    it 'does not leave an orphan definition or migration' do
      expect do
        run_generator ['bases']
      rescue ArgumentError => e
        raise unless e.message == 'View unmanaged does not exist'
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
