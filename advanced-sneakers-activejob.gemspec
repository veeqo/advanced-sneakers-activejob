# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'advanced_sneakers_activejob/version'

Gem::Specification.new do |spec|
  spec.name          = 'advanced-sneakers-activejob'
  spec.version       = AdvancedSneakersActiveJob::VERSION
  spec.authors       = ['Rustam Sharshenov', 'Vlad Bokov']
  spec.email         = ['rustam@sharshenov.com', 'vlad@lunatic.cat']

  spec.summary       = 'Advanced Sneakers adapter for ActiveJob'
  spec.description   = 'Advanced Sneakers adapter for ActiveJob'
  spec.homepage      = 'https://github.com/veeqo/advanced-sneakers-activejob'
  spec.license       = 'MIT'

  if spec.respond_to?(:metadata)
    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = spec.homepage
    spec.metadata['changelog_uri'] = 'https://github.com/veeqo/advanced-sneakers-activejob/blob/main/CHANGELOG.md'
  end

  spec.files = Dir['CHANGELOG.md', 'LICENSE.txt', 'README.md', 'lib/**/*']

  spec.required_ruby_version = '>= 2.5'

  spec.require_paths = ['lib']

  spec.add_dependency 'activejob', '>= 6.0'
  spec.add_dependency 'bunny-publisher', '~> 0.2.0'
  spec.add_dependency 'sneakers', '~> 2.7'

  spec.add_development_dependency 'appraisal', '~> 2.5.0'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'rabbitmq_http_api_client', '~> 1.13'
  spec.add_development_dependency 'rspec', '~> 3.0'
end
