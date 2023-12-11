# frozen_string_literal: true

RSpec.describe Scenic::Cascade do
  it 'has a version number', size: :small do
    expect(Scenic::Cascade::VERSION).to match_semver
  end
end
