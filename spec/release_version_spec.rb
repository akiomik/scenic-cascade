# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'tempfile'
require_relative '../lib/scenic/cascade/version'

# The executable has no Ruby class to describe.
# rubocop:disable RSpec/DescribeClass
RSpec.describe 'release-version', size: :small do
  let(:script) { File.expand_path('../bin/release-version', __dir__) }
  let(:output) { Tempfile.new('release-version') }
  let(:marker) { "#{output.path}.executed" }

  def validate(tag)
    Open3.capture3({ 'RELEASE_TAG' => tag, 'GITHUB_OUTPUT' => output.path }, 'bash', script)
  end

  after do
    FileUtils.rm_f(marker)
    output.close!
  end

  it 'outputs the version for a canonical release tag' do
    _stdout, _stderr, status = validate("v#{Scenic::Cascade::VERSION}")
    expect([status.success?, File.read(output.path)]).to eq([true, "version=#{Scenic::Cascade::VERSION}\n"])
  end

  it 'rejects a valid tag that differs from the gem version' do
    tag = "v#{Scenic::Cascade::VERSION.split('.').first.to_i + 1}.0.0"
    _stdout, stderr, status = validate(tag)
    expect([status.success?, File.size(output.path), stderr]).to eq(
      [false, 0, "Release tag #{tag} does not match gem version #{Scenic::Cascade::VERSION}\n"]
    )
  end

  %w[v01.2.3 v1.2.3.4 v1.2.3.rc1 1.2.3].each do |tag|
    it "rejects #{tag} without writing an output" do
      _stdout, _stderr, status = validate(tag)
      expect([status.success?, File.size(output.path)]).to eq([false, 0])
    end
  end

  it 'rejects shell syntax without executing it' do
    _stdout, _stderr, status = validate("v0.1.2$(touch #{marker})")
    expect([status.success?, File.exist?(marker)]).to eq([false, false])
  end
end
# rubocop:enable RSpec/DescribeClass
