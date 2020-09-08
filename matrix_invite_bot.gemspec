# frozen_string_literal: true

require_relative 'lib/matrix_invite_bot/version'

Gem::Specification.new do |spec|
  spec.name          = 'matrix_invite_bot'
  spec.version       = MatrixInviteBot::VERSION
  spec.authors       = ['Alexander Olofsson']
  spec.email         = ['alexander.olofsson@liu.se']

  spec.summary       = 'A Matrix bot for inviting users to communities and rooms'
  spec.description   = spec.summary
  spec.homepage      = 'https://gitlab.liu.se/ITI/matrix-invite-bot'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.3.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = 'https://gitlab.liu.se/ITI/matrix-invite-bot/-/commits/master'

  spec.extra_rdoc_files = %w[LICENSE.txt README.md]
  spec.files            = Dir['{bin,lib}/**/*'] + spec.extra_rdoc_files
  spec.executables      = 'matrix_invite_bot'

  spec.add_development_dependency 'mocha'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'test-unit'

  spec.add_dependency 'matrix_sdk', '~> 2'
end
