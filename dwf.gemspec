# frozen_string_literal: true
# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require_relative 'lib/dwf/version'

Gem::Specification.new do |spec|
  spec.name          = "dwf"
  spec.version       = Dwf::VERSION
  spec.authors       = ["dthtien"]
  spec.email         = ["tiendt2311@gmail.com"]

  spec.summary       = 'Gush cloned without ActiveJob but requried Sidekiq. This project is for researching DSL purpose'
  spec.description   = 'Workflow'
  spec.homepage      = 'https://github.com/dthtien/wf'
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.4.0"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = `git ls-files -z`.split("\x0")
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  # guide at: https://bundler.io/guides/creating_gem.html

  spec.add_development_dependency 'byebug', '~> 11.1.3'
  spec.add_development_dependency 'mock_redis', '~> 0.27.2'
  spec.add_dependency 'redis', '~> 4.2.0'
  spec.add_development_dependency 'rspec', '~> 3.2'
  spec.add_dependency 'sidekiq', '~> 6.2.0'
  spec.add_development_dependency 'simplecov'
end
