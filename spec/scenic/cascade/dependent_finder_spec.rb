# frozen_string_literal: true

RSpec.describe Scenic::Cascade::DependentFinder, size: :medium do
  describe '.view_dependents_of' do
    subject { Scenic::Cascade.view_dependents_of(name, recursive: recursive) }

    include_examples 'a dependent finder'
  end

  describe '.view_dependants_of' do
    subject { Scenic::Cascade.view_dependants_of(name, recursive: recursive) }

    include_examples 'a dependent finder'
  end
end
