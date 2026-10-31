# frozen_string_literal: true

RSpec.describe Scenic::Cascade::DefinitionFinder, size: :small do
  let(:name) { 'search_results' }
  let(:root) { Pathname.new(Dir.mktmpdir) }

  def write_definitions(*versions)
    versions.each do |version|
      path = Scenic::Definition.new(name, version).full_path
      path.dirname.mkpath
      path.write('SELECT 1')
    end
  end

  before { allow(Rails).to receive(:root).and_return(root) }
  after { FileUtils.remove_entry(root) }

  describe '.find_definitions_of' do
    subject(:actual) { Scenic::Cascade.find_definitions_of(name).map(&:version) }

    it 'returns no definitions when the view does not exist' do
      expect(actual).to eq([])
    end

    it 'returns consecutive definitions in version order' do
      write_definitions(1, 2, 3)
      expect(actual).to eq(%w[01 02 03])
    end

    it 'returns definitions across a version gap' do
      write_definitions(1, 3)
      expect(actual).to eq(%w[01 03])
    end

    it 'returns a definition when only a later version exists' do
      write_definitions(3)
      expect(actual).to eq(['03'])
    end

    it 'orders versions numerically beyond two digits' do
      write_definitions(100, 1, 99)
      expect(actual).to eq(%w[01 99 100])
    end

    it 'ignores version zero and similarly named files' do
      write_definitions(1)
      views = root.join('db/views')
      views.join('search_results_v00.sql').write('SELECT 1')
      views.join('search_results_extra_v02.sql').write('SELECT 1')

      expect(actual).to eq(['01'])
    end

    it 'ignores a directory with a definition filename' do
      write_definitions(1)
      root.join('db/views/search_results_v03.sql').mkpath

      expect(actual).to eq(['01'])
    end

    it 'rejects a noncanonical numeric version instead of choosing an older definition' do
      write_definitions(1)
      root.join('db/views/search_results_v3.sql').write('SELECT 1')

      expect { actual }.to raise_error(ArgumentError, /Noncanonical view definition/)
    end

    it 'returns the path of the existing definition across a gap' do
      write_definitions(1, 3)
      expect(Scenic::Cascade.find_definitions_of(name).last.full_path)
        .to eq(root.join('db/views/search_results_v03.sql'))
    end
  end

  describe '.find_latest_definition_of' do
    subject(:actual) { Scenic::Cascade.find_latest_definition_of(name) }

    it 'raises when the view does not exist' do
      expect { actual }.to raise_error(ArgumentError, 'View search_results does not exist')
    end

    it 'selects the latest version across a gap' do
      write_definitions(1, 3)
      expect(actual.version).to eq('03')
    end

    it 'selects a later version without version one' do
      write_definitions(3)
      expect(actual.version).to eq('03')
    end
  end
end
