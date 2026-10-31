# frozen_string_literal: true

RSpec.describe Scenic::Cascade::DependencyFinder, size: :medium do
  describe '.view_dependencies_of' do
    subject(:dependencies) { Scenic::Cascade.view_dependencies_of(name, recursive: recursive) }

    include_examples 'a dependency finder'

    context 'when view names overlap across schemas' do
      let(:recursive) { true }
      let(:name) { 'public.cross_reports' }
      let(:edges) { dependencies.map { |dependency| [dependency.from.name, dependency.to.name] } }

      before do
        ActiveRecord::Base.connection.execute('CREATE SCHEMA reporting')
        adapter = Scenic::Adapters::Postgres.new
        adapter.create_view('public.schema_bases', "SELECT 'public' AS bar")
        adapter.create_view('reporting.schema_bases', "SELECT 'reporting' AS bar")
        adapter.create_view('public.schema_reports', 'SELECT * FROM public.schema_bases')
        adapter.create_view('reporting.schema_reports', 'SELECT * FROM reporting.schema_bases')
        adapter.create_view('public.cross_reports', 'SELECT * FROM reporting.schema_reports')
      end

      it 'recurses through qualified dependencies without mixing schemas' do
        expect(edges).to contain_exactly(
          ['cross_reports', 'reporting.schema_reports'],
          ['reporting.schema_reports', 'reporting.schema_bases']
        )
      end
    end
  end
end
