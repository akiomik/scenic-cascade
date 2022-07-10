# frozen_string_literal: true

class DependencyLike
  attr_reader :from, :to

  def initialize(from:, to:)
    @from = from
    @to = to
  end
end

RSpec.describe Scenic::Dependencies::Dependency, size: :small do
  describe '#==' do
    subject { this == that }

    let(:this) { described_class.new(from: 'view1', to: 'view2') }

    context 'when that is the same instance' do
      let(:that) { this }

      it { is_expected.to be true }
    end

    context 'when that has same values' do
      let(:that) { described_class.new(from: 'view1', to: 'view2') }

      it { is_expected.to be true }
    end

    context 'when that is not a Dependency' do
      let(:that) { DependencyLike.new(from: 'view1', to: 'view2') }

      it { is_expected.to be true }
    end

    context 'when that has defferent from' do
      let(:that) { described_class.new(from: 'view2', to: 'view2') }

      it { is_expected.to be false }
    end

    context 'when that has defferent to' do
      let(:that) { described_class.new(from: 'view1', to: 'view1') }

      it { is_expected.to be false }
    end
  end

  describe '.from_hash_list' do
    subject { described_class.from_hash_list(hash_list) }

    context 'when hash_list is empty' do
      let(:hash_list) { [] }

      it { is_expected.to match [] }
    end

    context 'when hash_list is not empty' do
      let(:hash_list) do
        [{
          'from' => 'view2',
          'to' => 'view1'
        }, {
          'from' => 'view3',
          'to' => 'view2'
        }, {
          'from' => 'view3',
          'to' => 'view1'
        }]
      end

      let(:expected) do
        [
          described_class.new(from: 'view2', to: 'view1'),
          described_class.new(from: 'view3', to: 'view2'),
          described_class.new(from: 'view3', to: 'view1')
        ]
      end

      it { is_expected.to match expected }
    end
  end
end
