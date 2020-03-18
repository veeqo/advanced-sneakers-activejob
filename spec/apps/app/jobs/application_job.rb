# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  def perform(msg)
    logger.info("Performing '#{msg}'")
    raise StandardError, 'Some error message' if msg.include?('fail')
  end
end
