# frozen_string_literal: true

RSpec.describe Scenic::Cascade::DependencyFinder, size: :medium do
  describe '.view_dependencies_of' do
    subject(:dependencies) { Scenic::Cascade.view_dependencies_of(name, recursive:) }

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

    context 'when dependencies converge' do
      before do
        adapter = Scenic::Adapters::Postgres.new
        adapter.create_view('perf_root', "SELECT 'value' AS bar")
        adapter.create_view('perf_left', 'SELECT * FROM perf_root')
        adapter.create_view('perf_right', 'SELECT * FROM perf_root')
        adapter.create_view('perf_join', 'SELECT * FROM perf_left UNION SELECT * FROM perf_right')
        adapter.create_view('perf_leaf', 'SELECT * FROM perf_join')
      end

      it 'retains all dependency paths' do
        result = Scenic::Cascade.view_dependencies_of('perf_leaf', recursive: true)

        expect(result.count { |dep| dep.to.name == 'perf_root' }).to eq(2)
      end

      it 'queries each view once' do
        connection = ActiveRecord::Base.connection
        allow(connection).to receive(:select_all).and_call_original

        Scenic::Cascade.view_dependencies_of('perf_leaf', recursive: true)

        expect(connection).to have_received(:select_all).exactly(5).times
      end
    end
  end
end
