# frozen_string_literal: true

RSpec.describe Scenic::Dependencies do
  it 'has a version number', size: :small do
    expect(Scenic::Dependencies::VERSION).to match_semver
  end
end
