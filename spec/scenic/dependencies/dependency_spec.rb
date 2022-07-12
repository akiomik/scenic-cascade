# frozen_string_literal: true

class DependencyLike
  attr_reader :from, :to

  def initialize(from:, to:)
    @from = from
    @to = to
  end
end

RSpec.describe Scenic::Dependencies::Dependency, size: :small do
  describe '.new' do
    subject(:new) { described_class.new(from: from, to: to) }

    context 'when parameters is valid' do
      let(:from) { 'view1' }
      let(:to) { 'view2' }

      it { expect { new }.not_to raise_error }
      it { is_expected.to have_attributes(from: from, to: to) }
    end

    context 'when nil is included in parameters' do
      let(:from) { nil }
      let(:to) { 'view2' }

      it { expect { new }.to raise_error TypeError }
    end
  end

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

  describe '.from_hash' do
    subject { described_class.from_hash(hash) }

    let(:hash) { { 'from' => 'view2', 'to' => 'view1' } }
    let(:expected) { described_class.new(from: 'view2', to: 'view1') }

    it { is_expected.to eq expected }
    it { is_expected.to be_a described_class }
  end
end
