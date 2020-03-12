# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  def perform(msg)
    logger.info("Performing '#{msg}'")
    raise if msg.include?('fail')
  end
end
