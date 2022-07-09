# frozen_string_literal: true

RSpec.describe Scenic::Dependencies do
  it 'has a version number' do
    expect(Scenic::Dependencies::VERSION).not_to be_nil
  end
end
