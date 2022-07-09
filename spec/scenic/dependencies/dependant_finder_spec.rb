# frozen_string_literal: true

RSpec.describe Scenic::Dependencies::DependantFinder do
  shared_examples 'a dependant finder' do
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

      it { is_expected.to eq [] }
    end

    context 'when the target view has no dependants' do
      let(:name) { 'view3' }

      it { is_expected.to eq [] }
    end

    context 'when the target view has dependants' do
      let(:name) { 'view2' }

      let(:expected) do
        [{
          'to' => 'view2',
          'from' => 'view3'
        }]
      end

      it { is_expected.to eq expected }
    end

    context 'when the target view has nested dependants and recursive is false' do
      let(:name) { 'view1' }

      let(:expected) do
        [{
          'to' => 'view1',
          'from' => 'view2'
        }, {
          'to' => 'view1',
          'from' => 'view3'
        }]
      end

      it { is_expected.to eq expected }
    end

    context 'when the target view has nested dependants and recursive is true' do
      let(:name) { 'view1' }
      let(:recursive) { true }

      let(:expected) do
        [{
          'to' => 'view1',
          'from' => 'view2'
        }, {
          'to' => 'view2',
          'from' => 'view3'
        }, {
          'to' => 'view1',
          'from' => 'view3'
        }]
      end

      it { is_expected.to eq expected }
    end
  end

  describe '.view_dependants_of' do
    subject { Scenic::Dependencies.view_dependants_of(name, recursive: recursive) }

    include_examples 'a dependant finder'
  end

  describe '.view_dependents_of' do
    subject { Scenic::Dependencies.view_dependents_of(name, recursive: recursive) }

    include_examples 'a dependant finder'
  end
end
