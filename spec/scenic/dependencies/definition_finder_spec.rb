# frozen_string_literal: true

RSpec.describe Scenic::Dependencies::DefinitionFinder, size: :small do
  describe '.find_definitions_of' do
    subject(:actual) { Scenic::Dependencies.find_definitions_of(name) }

    let(:name) { 'search_results' }
    let(:root) { 'testapp' }

    before { allow(Rails).to receive(:root).and_return(Pathname.new(root)) }

    context 'when a definition does not exist' do
      it { is_expected.to eq [] }
    end

    context 'when a definition exists' do
      let(:version) { 7 }
      let(:expected) { (1..version).map { |i| Pathname.new("#{root}/db/views/#{name}_v0#{i}.sql") } }

      before { allow(File).to receive(:exist?).and_return(*[true] * version, false) }

      it { expect(actual.map(&:full_path)).to eq expected }
    end
  end

  describe '.find_latest_definition_of' do
    subject(:actual) { Scenic::Dependencies.find_latest_definition_of(name) }

    let(:name) { 'search_results' }
    let(:root) { 'testapp' }

    before { allow(Rails).to receive(:root).and_return(Pathname.new(root)) }

    context 'when a definition does not exist' do
      it { expect { actual }.to raise_error ArgumentError }
    end

    context 'when a definition exists' do
      let(:version) { 7 }

      before { allow(File).to receive(:exist?).and_return(*[true] * version, false) }

      it { expect(actual.full_path).to eq Pathname.new("#{root}/db/views/#{name}_v0#{version}.sql") }
    end
  end
end
