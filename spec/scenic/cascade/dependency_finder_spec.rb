# frozen_string_literal: true

RSpec.describe Scenic::Cascade::DependencyFinder, size: :medium do
  describe '.view_dependencies_of' do
    subject { Scenic::Cascade.view_dependencies_of(name, recursive: recursive) }

    include_examples 'a dependency finder'
  end
end
