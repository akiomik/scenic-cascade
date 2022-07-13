# frozen_string_literal: true

class RailsRootMock
  attr_reader :root

  def initialize(root)
    @root = root
  end

  def join(*paths)
    [root, *paths].join('/')
  end
end

RSpec.describe Scenic::Dependencies::DefinitionFinder, size: :small do
  describe '.find_definitions_of' do
    subject(:actual) { Scenic::Dependencies.find_definitions_of(name) }

    let(:name) { 'searches' }
    let(:root) { '.' }
    let(:root_mock) { RailsRootMock.new(root) }

    before { allow(Rails).to receive(:root).and_return(root_mock) }

    context 'when a definition does not exist' do
      it { is_expected.to eq [] }
    end

    context 'when a definition exists' do
      let(:version) { 7 }
      let(:expected) { (1..version).map { |i| "#{root}/db/views/#{name}_v0#{i}.sql" } }

      before { allow(File).to receive(:exist?).and_return(*[true] * version, false) }

      it { expect(actual.map(&:full_path)).to eq expected }
    end
  end

  describe '.find_latest_definition_of' do
    subject(:actual) { Scenic::Dependencies.find_latest_definition_of(name) }

    let(:name) { 'searches' }
    let(:root) { '.' }
    let(:root_mock) { RailsRootMock.new(root) }

    before { allow(Rails).to receive(:root).and_return(root_mock) }

    context 'when a definition does not exist' do
      it { expect { actual }.to raise_error ArgumentError }
    end

    context 'when a definition exists' do
      let(:version) { 7 }

      before { allow(File).to receive(:exist?).and_return(*[true] * version, false) }

      it { expect(actual.full_path).to eq "#{root}/db/views/#{name}_v0#{version}.sql" }
    end
  end
end
