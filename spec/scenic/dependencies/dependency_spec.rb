# frozen_string_literal: true

class DependencyLike
  attr_reader :from, :to

  def initialize(from:, to:)
    @from = from
    @to = to
  end
end

RSpec.describe Scenic::Dependencies::Dependency, size: :small do
  let(:view1) { Scenic::Dependencies::View.new(name: 'view1', materialized: false) }
  let(:view2) { Scenic::Dependencies::View.new(name: 'view2', materialized: true) }

  describe '.new' do
    subject(:new) { described_class.new(from: view2, to: view1) }

    context 'when parameters are Scenic::Dependencies::View' do
      it { expect { new }.not_to raise_error }
      it { is_expected.to have_attributes(from: view2, to: view1) }
    end

    context 'when nil is included in parameters' do
      let(:view1) { nil }

      it { expect { new }.to raise_error TypeError }
    end
  end

  describe '#==' do
    subject { this == that }

    let(:this) { described_class.new(from: view2, to: view1) }

    context 'when that is the same instance' do
      let(:that) { this }

      it { is_expected.to be true }
    end

    context 'when that has the same values' do
      let(:that) { described_class.new(from: view2, to: view1) }

      it { is_expected.to be true }
    end

    context 'when that has the same values but not Scenic::Dependencies::Dependency' do
      let(:that) { DependencyLike.new(from: view2, to: view1) }

      it { is_expected.to be true }
    end

    context 'when that has defferent `from`' do
      let(:that) { described_class.new(from: view1, to: view1) }

      it { is_expected.to be false }
    end

    context 'when that has defferent `to' do
      let(:that) { described_class.new(from: view2, to: view2) }

      it { is_expected.to be false }
    end
  end

  describe '.from_hash' do
    subject { described_class.from_hash(hash) }

    let(:hash) { { 'from' => 'view2', 'from_materialized' => true, 'to' => 'view1', 'to_materialized' => false } }

    it { is_expected.to eq described_class.new(from: view2, to: view1) }
    it { is_expected.to be_a described_class }
  end
end
