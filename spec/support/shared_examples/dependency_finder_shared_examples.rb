# frozen_string_literal: true

shared_examples 'a dependency finder' do
  let(:recursive) { false }
  let(:adapter) { Scenic::Adapters::Postgres.new }

  before do
    adapter.create_materialized_view(
      'view1',
      "SELECT 'foo' AS bar"
    )
    adapter.create_materialized_view(
      'view2',
      'SELECT * FROM view1'
    )
    adapter.create_materialized_view(
      'view3',
      'SELECT * FROM view1 UNION SELECT * FROM view2'
    )
  end

  context 'when the target view does not exist' do
    let(:name) { 'view0' }

    it { is_expected.to match [] }
  end

  context 'when the target view has no dependencies' do
    let(:name) { 'view1' }

    it { is_expected.to match [] }
  end

  context 'when the target view has dependencies' do
    let(:name) { 'view2' }

    let(:expected) { [Scenic::Dependencies::Dependency.new(from: 'view2', to: 'view1')] }

    it { is_expected.to match expected }
  end

  context 'when the target view has nested dependencies and recursive is false' do
    let(:name) { 'view3' }

    let(:expected) do
      [
        Scenic::Dependencies::Dependency.new(from: 'view3', to: 'view1'),
        Scenic::Dependencies::Dependency.new(from: 'view3', to: 'view2')
      ]
    end

    it { is_expected.to match expected }
  end

  context 'when the target view has nested dependencies and recursive is true' do
    let(:name) { 'view3' }
    let(:recursive) { true }

    let(:expected) do
      [
        Scenic::Dependencies::Dependency.new(from: 'view3', to: 'view1'),
        Scenic::Dependencies::Dependency.new(from: 'view3', to: 'view2'),
        Scenic::Dependencies::Dependency.new(from: 'view2', to: 'view1')
      ]
    end

    it { is_expected.to match expected }
  end
end