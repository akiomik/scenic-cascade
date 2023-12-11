# frozen_string_literal: true

require 'rails_helper'

require 'generators/scenic/view/cascade/cascade_generator'

# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe Scenic::Generators::View::CascadeGenerator, size: :medium, type: :generator do
  let(:view_name) { 'search_results' }
  let(:tempdir) { Dir.mktmpdir }

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

    before do
      pp tempdir

      adapter = Scenic::Adapters::Postgres.new
      adapter.create_view(
        view_name,
        "SELECT 'foo' AS bar"
      )
      adapter.create_materialized_view(
        'seconds',
        'SELECT * FROM firsts'
      )
      adapter.create_view(
        'thirds',
        'SELECT * FROM firsts UNION SELECT * FROM seconds'
      )

      # Setup firsts
      prev_view_definition = file("db/views/#{view_name}_v01.sql")
      FileUtils.mkpath(File.dirname(prev_view_definition))
      FileUtils.touch(prev_view_definition)

      # Setup seconds
      FileUtils.touch(file('db/views/seconds_v01.sql'))
      FileUtils.touch(file('db/views/seconds_v02.sql'))
      FileUtils.touch(file('db/views/seconds_v03.sql'))

      # Setup thirds
      FileUtils.touch(file('db/views/thirds_v01.sql'))
      FileUtils.touch(file('db/views/thirds_v02.sql'))

      run_generator [view_name]
    end

    it { expect(migration).to be_a_migration }
    it { expect(view_definition).to exist }
    it { expect(migration).to contain_migration(:drop_view, ':thirds', revert_to_version: 2, materialized: false) }
    it { expect(migration).to contain_migration(:drop_view, ':seconds', revert_to_version: 3, materialized: true) }
    it { expect(migration).to contain_migration(:create_view, ':seconds', version: 3, materialized: true) }
    it { expect(migration).to contain_migration(:create_view, ':thirds', version: 2, materialized: false) }
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
