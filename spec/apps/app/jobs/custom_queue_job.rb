# frozen_string_literal: true

class CustomQueueJob < ApplicationJob
  queue_as :custom
end
