# frozen_string_literal: true

require 'rubygems/package'
require 'fileutils'
require 'open3'
require 'tmpdir'

RSpec.describe Gem::Package, size: :small do
  let(:files) do
    Dir.mktmpdir do |directory|
      %w[lib sig README.md CHANGELOG.md LICENSE scenic-cascade.gemspec
         .env Gemfile Gemfile.lock Dockerfile rbs_collection.lock.yaml].each do |path|
        FileUtils.cp_r(path, directory)
      end

      output, error, status = Open3.capture3('gem', 'build', 'scenic-cascade.gemspec', chdir: directory)
      raise "gem build failed: #{output}\n#{error}" unless status.success?

      gem_file = Dir.glob(File.join(directory, 'scenic-cascade-*.gem')).fetch(0)
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
