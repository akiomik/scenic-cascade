# frozen_string_literal: true

require_relative 'lib/scenic/cascade/version'

Gem::Specification.new do |spec|
  spec.name = 'scenic-cascade'
  spec.version = Scenic::Cascade::VERSION
  spec.authors = ['Akiomi Kamakura']
  spec.email = ['akiomik@gmail.com']

  spec.summary = 'A migration scenic file generator that supports cascading view updates'
  spec.description = spec.summary # TODO
  spec.homepage = 'https://github.com/akiomik/scenic-cascade'
  spec.required_ruby_version = '>= 2.6.0'
  spec.licenses = ['Apache-2.0']

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/akiomik/scenic-cascade'
  spec.metadata['changelog_uri'] = 'https://github.com/akiomik/scenic-cascade/blob/main/CHANGELOG.md'

  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'scenic', '~> 1.0'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
