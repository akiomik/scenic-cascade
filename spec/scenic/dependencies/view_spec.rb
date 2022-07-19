# frozen_string_literal: true

class ViewLike
  attr_reader :name

  def initialize(name:, materialized:)
    @name = name
    @materialized = materialized
  end

  def materialized?
    @materialized
  end
end

RSpec.describe Scenic::Dependencies::View, size: :small do
  describe '.new' do
    subject(:new) { described_class.new(name: name, materialized: materialized) }

    context 'when parameters is valid' do
      let(:name) { 'view1' }
      let(:materialized) { false }

      it { expect { new }.not_to raise_error }
      it { is_expected.to have_attributes(name: name, materialized?: materialized) }
    end

    context 'when name is nil' do
      let(:name) { nil }
      let(:materialized) { false }

      it { expect { new }.to raise_error TypeError }
    end

    context 'when materialized is nil' do
      let(:name) { 'view1' }
      let(:materialized) { nil }

      it { expect { new }.to raise_error TypeError }
    end
  end

  describe '#formatted_name' do
    subject { view.formatted_name }

    let(:view) { described_class.new(name: name, materialized: true) }

    context 'when "." is included in name' do
      let(:name) { 'database.view' }

      it { is_expected.to eq '"database.view"' }
    end

    context 'when "." is not included in name' do
      let(:name) { 'view' }

      it { is_expected.to eq ':view' }
    end
  end

  describe '#==' do
    subject { this == that }

    let(:name) { 'view1' }
    let(:materialized) { false }
    let(:this) { described_class.new(name: name, materialized: materialized) }

    context 'when that is the same instance' do
      let(:that) { this }

      it { is_expected.to be true }
    end

    context 'when that has the same values' do
      let(:that) { described_class.new(name: name, materialized: materialized) }

      it { is_expected.to be true }
    end

    context 'when that is not a View but has the same values' do
      let(:that) { ViewLike.new(name: name, materialized: materialized) }

      it { is_expected.to be true }
    end

    context 'when that has defferent `name`' do
      let(:that) { described_class.new(name: 'view2', materialized: materialized) }

      it { is_expected.to be false }
    end

    context 'when that has defferent `materialized`' do
      let(:that) { described_class.new(name: name, materialized: true) }

      it { is_expected.to be false }
    end
  end

  describe '.to_s' do
    subject { view.to_s }

    let(:view) { described_class.new(name: 'view1', materialized: materialized) }

    context 'when materialized' do
      let(:materialized) { true }

      it { is_expected.to eq 'view1 (MV)' }
    end

    context 'when not materialized' do
      let(:materialized) { false }

      it { is_expected.to eq 'view1 (V)' }
    end
  end
end
