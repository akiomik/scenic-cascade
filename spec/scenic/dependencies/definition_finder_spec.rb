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
  describe '.find_latest_definition_of' do
    subject(:expected) { Scenic::Dependencies.find_latest_definition_of(name) }

    let(:name) { 'searches' }
    let(:root_mock) { RailsRootMock.new('.') }

    before { allow(Rails).to receive(:root).and_return(root_mock) }

    context 'when a definition does not exist' do
      it { expect { expected }.to raise_error ArgumentError }
    end

    context 'when a definition exists' do
      let(:version) { 7 }
      let(:trues) { [true] * version }

      before { allow(File).to receive(:exist?).and_return(*trues, false) }

      it { expect(expected.full_path).to eq "./db/views/#{name}_v0#{version}.sql" }
    end
  end
end
