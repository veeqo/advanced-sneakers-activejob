# frozen_string_literal: true

RSpec.configure do |config|
  # This tag temporarily sets requested configuration and restores previuos values after test run
  config.around :each, :with_config do |ex|
    config = AdvancedSneakersActiveJob.config
    was = {}

    ex.metadata.fetch(:with_config).each do |key, value|
      was[key] = config.send(key.to_sym)
      config.send(:"#{key}=", value)
    end

    ex.run

    was.each { |key, value| config.send(:"#{key}=", value) }
  end
end
