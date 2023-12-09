# frozen_string_literal: true

class DependencyLike
  attr_reader :from, :to

  def initialize(from:, to:)
    @from = from
    @to = to
  end
end

RSpec.describe Scenic::Dependencies::Dependency, size: :small do
  let(:view_first) { Scenic::Dependencies::View.new(name: 'view_first', materialized: false) }
  let(:view_second) { Scenic::Dependencies::View.new(name: 'view_second', materialized: true) }

  describe '.new' do
    subject(:new) { described_class.new(from: view_second, to: view_first) }

    context 'when parameters are Scenic::Dependencies::View' do
      it { expect { new }.not_to raise_error }
      it { is_expected.to have_attributes(from: view_second, to: view_first) }
    end

    context 'when nil is included in parameters' do
      let(:view_first) { nil }

      it { expect { new }.to raise_error TypeError }
    end
  end

  describe '#==' do
    subject { this == that }

    let(:this) { described_class.new(from: view_second, to: view_first) }

    context 'when that is the same instance' do
      let(:that) { this }

      it { is_expected.to be true }
    end

    context 'when that has the same values' do
      let(:that) { described_class.new(from: view_second, to: view_first) }

      it { is_expected.to be true }
    end

    context 'when that has the same values but not Scenic::Dependencies::Dependency' do
      let(:that) { DependencyLike.new(from: view_second, to: view_first) }

      it { is_expected.to be true }
    end

    context 'when that has defferent `from`' do
      let(:that) { described_class.new(from: view_first, to: view_first) }

      it { is_expected.to be false }
    end

    context 'when that has defferent `to' do
      let(:that) { described_class.new(from: view_second, to: view_second) }

      it { is_expected.to be false }
    end
  end

  describe '.from_hash' do
    subject { described_class.from_hash(hash) }

    let(:hash) do
      { 'from' => 'view_second', 'from_materialized' => true, 'to' => 'view_first', 'to_materialized' => false }
    end

    it { is_expected.to eq described_class.new(from: view_second, to: view_first) }
    it { is_expected.to be_a described_class }
  end
end
