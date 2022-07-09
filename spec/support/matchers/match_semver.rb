# frozen_string_literal: true

RSpec::Matchers.define :match_semver do
  match do |actual|
    # rubocop:disable Style/LineLength
    actual.match?(/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$/)
    # rubocop:enable Style/LineLength
  end
end
