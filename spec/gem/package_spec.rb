# frozen_string_literal: true

require 'rubygems/package'
require 'tmpdir'

RSpec.describe Gem::Package, size: :small do
  let(:files) do
    specification = Gem::Specification.load('scenic-cascade.gemspec')
    Dir.mktmpdir do |directory|
      gem_file = File.join(directory, "scenic-cascade-#{specification.version}.gem")
      described_class.build(specification, false, false, gem_file)
      described_class.new(gem_file).contents
    end
  end

  it 'contains runtime code, type signatures, and documentation' do
    expect(files).to include('lib/scenic/cascade.rb',
                             'lib/generators/scenic/view/cascade/templates/db/migrate/update_view.rb.erb',
                             'sig/scenic/cascade.rbs', 'README.md', 'CHANGELOG.md', 'LICENSE')
  end

  it 'excludes development configuration' do
    expect(files).not_to include('.env', 'Gemfile', 'Gemfile.lock', 'rbs_collection.lock.yaml', 'Dockerfile')
  end
end
