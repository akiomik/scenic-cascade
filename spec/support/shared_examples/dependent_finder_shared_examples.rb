# frozen_string_literal: true

shared_examples 'a dependent finder' do
  let(:recursive) { false }
  let(:view_first) { Scenic::Cascade::View.new(name: 'view_first', materialized: false) }
  let(:view_second) { Scenic::Cascade::View.new(name: 'view_second', materialized: true) }
  let(:view_third) { Scenic::Cascade::View.new(name: 'view_third', materialized: false) }

  before do
    adapter = Scenic::Adapters::Postgres.new
    adapter.create_view(
      'view_first',
      "SELECT 'foo' AS bar"
    )
    adapter.create_materialized_view(
      'view_second',
      'SELECT * FROM view_first'
    )
    adapter.create_view(
      'view_third',
      'SELECT * FROM view_first UNION SELECT * FROM view_second'
    )
  end

  context 'when the target view does not exist' do
    let(:name) { 'view0' }

    it { is_expected.to match [] }
  end

  context 'when the target view has no dependents' do
    let(:name) { 'view_third' }

    it { is_expected.to match [] }
  end

  context 'when the target view has dependents' do
    let(:name) { 'view_second' }

    it { is_expected.to match [Scenic::Cascade::Dependency.new(from: view_third, to: view_second)] }
  end

  context 'when the target view has nested dependents and recursive is false' do
    let(:name) { 'view_first' }

    let(:expected) do
      [
        Scenic::Cascade::Dependency.new(from: view_second, to: view_first),
        Scenic::Cascade::Dependency.new(from: view_third, to: view_first)
      ]
    end

    it { is_expected.to match expected }
  end

  context 'when the target view has nested dependents and recursive is true' do
    let(:name) { 'view_first' }
    let(:recursive) { true }

    let(:expected) do
      [
        Scenic::Cascade::Dependency.new(from: view_second, to: view_first),
        Scenic::Cascade::Dependency.new(from: view_third, to: view_second),
        Scenic::Cascade::Dependency.new(from: view_third, to: view_first)
      ]
    end

    it { is_expected.to match expected }
  end

  context 'when recursive dependents extend beyond two levels' do
    let(:name) { 'root_chain' }
    let(:recursive) { true }

    let(:expected) do
      [
        Scenic::Cascade::Dependency.new(
          from: Scenic::Cascade::View.new(name: 'mid_one', materialized: false),
          to: Scenic::Cascade::View.new(name: 'root_chain', materialized: false)
        ),
        Scenic::Cascade::Dependency.new(
          from: Scenic::Cascade::View.new(name: 'mid_two', materialized: false),
          to: Scenic::Cascade::View.new(name: 'mid_one', materialized: false)
        ),
        Scenic::Cascade::Dependency.new(
          from: Scenic::Cascade::View.new(name: 'leaf_chain', materialized: false),
          to: Scenic::Cascade::View.new(name: 'mid_two', materialized: false)
        )
      ]
    end

    before do
      adapter = Scenic::Adapters::Postgres.new
      adapter.create_view('root_chain', "SELECT 'foo' AS bar")
      adapter.create_view('mid_one', 'SELECT * FROM root_chain')
      adapter.create_view('mid_two', 'SELECT * FROM mid_one')
      adapter.create_view('leaf_chain', 'SELECT * FROM mid_two')
    end

    it { is_expected.to match expected }
  end
end
