# frozen_string_literal: true

require_relative 'lib/lpsolver/version'

Gem::Specification.new do |spec|
  spec.name          = 'lpsolver'
  spec.version       = LpSolver::VERSION
  spec.authors       = ['David Siaw']
  spec.email         = ['874280+davidsiaw@users.noreply.github.com']

  spec.summary       = 'HiGHS LP/MIP/QP solver for Ruby'
  spec.description   = 'A Ruby gem providing access to the HiGHS linear, quadratic, and mixed-integer programming solver via CLI.'
  spec.homepage      = 'https://github.com/davidsiaw/lpsolver'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.0')

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/davidsiaw/lpsolver'
  spec.metadata['changelog_uri'] = 'https://github.com/davidsiaw/lpsolver'
  spec.metadata['documentation_uri'] = 'https://davidsiaw.github.io/lpsolver'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.add_development_dependency 'rake-compiler', '~> 1.2'

  spec.files         = Dir['{exe,data,lib,ext}/**/*'] + %w[Gemfile lpsolver.gemspec README.md LICENSE.txt]
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.extensions    = %w[ext/lpsolver/extconf.rb]
end
