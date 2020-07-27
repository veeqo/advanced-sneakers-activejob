# frozen_string_literal: true

module AdvancedSneakersActiveJob
  # Rails integration
  class Railtie < ::Rails::Railtie
    rake_tasks do
      require 'advanced_sneakers_activejob/tasks'
    end
  end
end
