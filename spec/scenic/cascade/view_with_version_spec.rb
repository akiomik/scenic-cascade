# frozen_string_literal: true

require 'scenic/cascade/view_with_version'

class ViewWithVersionLike
  attr_reader :name, :version

  def initialize(name:, version:, materialized:)
    @name = name
    @version = version
    @materialized = materialized
  end

  def materialized?
    @materialized
  end
end

RSpec.describe Scenic::Cascade::ViewWithVersion, size: :small do
  describe '.new' do
    subject(:new) { described_class.new(name: name, version: version, materialized: materialized) }

    let(:name) { 'view1' }
    let(:version) { 2 }
    let(:materialized) { false }

    context 'when parameters is valid' do
      it { expect { new }.not_to raise_error }
      it { is_expected.to have_attributes(name: name, version: version, materialized?: materialized) }
    end

    context 'when name is nil' do
      let(:name) { nil }

      it { expect { new }.to raise_error TypeError }
    end

    context 'when version is nil' do
      let(:version) { nil }

      it { expect { new }.to raise_error TypeError }
    end

    context 'when materialized is nil' do
      let(:materialized) { nil }

      it { expect { new }.to raise_error TypeError }
    end
  end

  describe '#==' do
    subject { this == that }

    let(:name) { 'view1' }
    let(:version) { 2 }
    let(:materialized) { false }
    let(:this) { described_class.new(name: name, version: version, materialized: materialized) }

    context 'when that is the same instance' do
      let(:that) { this }

      it { is_expected.to be true }
    end

    context 'when that has the same values' do
      let(:that) { described_class.new(name: name, version: version, materialized: materialized) }

      it { is_expected.to be true }
    end

    context 'when that is not a View but has the same values' do
      let(:that) { ViewWithVersionLike.new(name: name, version: version, materialized: materialized) }

      it { is_expected.to be true }
    end

    context 'when that has defferent `name`' do
      let(:that) { described_class.new(name: 'view2', version: version, materialized: materialized) }

      it { is_expected.to be false }
    end

    context 'when that has defferent `version`' do
      let(:that) { described_class.new(name: name, version: 1, materialized: materialized) }

      it { is_expected.to be false }
    end

    context 'when that has defferent `materialized`' do
      let(:that) { described_class.new(name: name, version: version, materialized: true) }

      it { is_expected.to be false }
    end
  end

  describe '.to_s' do
    subject { view.to_s }

    let(:view) { described_class.new(name: 'view1', version: 2, materialized: materialized) }

    context 'when materialized' do
      let(:materialized) { true }

      it { is_expected.to eq 'view1_v02 (MV)' }
    end

    context 'when not materialized' do
      let(:materialized) { false }

      it { is_expected.to eq 'view1_v02 (V)' }
    end
  end

  describe '.inspect' do
    subject { view.inspect }

    let(:view) { described_class.new(name: 'view1', version: 2, materialized: true) }

    it { is_expected.to eq view.to_s }
  end
end
