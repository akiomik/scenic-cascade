# frozen_string_literal: true

RSpec.describe Scenic::Dependencies do
  it 'has a version number' do
    expect(Scenic::Dependencies::VERSION).to match_semver
  end
end
