# frozen_string_literal: true

require_relative 'lib/matrix_invite_bot/version'

Gem::Specification.new do |spec|
  spec.name          = "matrix_invite_bot"
  spec.version       = MatrixInviteBot::VERSION
  spec.authors       = ["Alexander Olofsson"]
  spec.email         = ["ace@haxalot.com"]

  spec.summary       = 'Hello world' #%q{TODO: Write a short summary, because RubyGems requires one.}
  spec.description   = spec.summary #%q{TODO: Write a longer description or delete this line.}
  spec.homepage      = 'https://liu.se' #"TODO: Put your gem's website or public repo URL here."
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["homepage_uri"] = spec.homepage
  # spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  spec.extra_rdoc_files = %w[LICENSE.txt README.md]
  spec.files            = Dir['lib/**'] + spec.extra_rdoc_files

  spec.add_development_dependency 'mocha'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'test-unit'

  spec.add_dependency 'matrix_sdk'
end
