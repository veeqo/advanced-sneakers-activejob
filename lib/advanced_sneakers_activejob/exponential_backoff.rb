# frozen_string_literal: true

module AdvancedSneakersActiveJob
  # Calculating exponential backoff by formulas with randomization leads to numerous RabbitMQ queues.
  EXPONENTIAL_BACKOFF = {
    1 => 3,       # 3 seconds
    2 => 30,      # 30 seconds
    3 => 90,      # 1.5 minutes
    4 => 240,     # 4 minutes
    5 => 600,     # 10 minutes
    6 => 1200,    # 20 minutes
    7 => 2400,    # 40 minutes
    8 => 3600,    # 1 hour
    9 => 7200,    # 2 hours
    10 => 10_800, # 3 hours
    11 => 14_400, # 4 hours
    12 => 21_600, # 6 hours
    13 => 28_800, # 8 hours
    14 => 36_000, # 10 hours
    15 => 50_400, # 14 hours
    16 => 64_800, # 18 hours
    17 => 86_400  # 24 hours
  }.tap { |h| h.default = 86_400 }.freeze
end
