# frozen_string_literal: true

RSpec.describe Scenic::Cascade::DependentFinder, size: :medium do
  describe '.view_dependents_of' do
    subject(:dependencies) { Scenic::Cascade.view_dependents_of(name, recursive: recursive) }

    include_examples 'a dependent finder'

    context 'when view names overlap across schemas' do
      let(:recursive) { true }
      let(:name) { 'reporting.schema_bases' }
      let(:edges) { dependencies.map { |dependency| [dependency.from.name, dependency.to.name] } }

      before do
        ActiveRecord::Base.connection.execute('CREATE SCHEMA reporting')
        adapter = Scenic::Adapters::Postgres.new
        adapter.create_view('public.schema_bases', "SELECT 'public' AS bar")
        adapter.create_view('reporting.schema_bases', "SELECT 'reporting' AS bar")
        adapter.create_view('public.schema_reports', 'SELECT * FROM public.schema_bases')
        adapter.create_view('reporting.schema_reports', 'SELECT * FROM reporting.schema_bases')
        adapter.create_view('reporting.only_reporting', 'SELECT * FROM reporting.schema_bases')
        adapter.create_view('public.cross_reports', 'SELECT * FROM reporting.schema_reports')
      end

      it 'recurses through the qualified dependent and excludes the unrelated view' do
        expect(edges).to contain_exactly(
          ['reporting.only_reporting', 'reporting.schema_bases'],
          ['reporting.schema_reports', 'reporting.schema_bases'],
          ['cross_reports', 'reporting.schema_reports']
        )
      end

      it 'resolves an unqualified name through PostgreSQL search_path' do
        names = Scenic::Cascade.view_dependents_of('schema_bases').map { |dependency| dependency.from.name }
        expect(names).to eq(['schema_reports'])
      end
    end
  end

  describe '.view_dependants_of' do
    subject { Scenic::Cascade.view_dependants_of(name, recursive: recursive) }

    include_examples 'a dependent finder'
  end
end
