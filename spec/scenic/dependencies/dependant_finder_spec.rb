# frozen_string_literal: true

RSpec.describe Scenic::Dependencies::DependantFinder do
  describe '.view_dependants_of' do
    subject { Scenic::Dependencies.view_dependants_of(name, recursive: recursive) }

    include_examples 'a dependant finder'
  end

  describe '.view_dependents_of' do
    subject { Scenic::Dependencies.view_dependents_of(name, recursive: recursive) }

    include_examples 'a dependant finder'
  end
end
