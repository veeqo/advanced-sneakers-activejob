# frozen_string_literal: true

module LogHelpers
  def logs(name, filters: %i[job_id created_at])
    text = File.open(logs_path.join("#{name}.log")).read

    {
      job_id: /\(Job ID[^\)]+\) /,
      created_at: /enqueued at [^ ]+ /
    }.each do |filter, regex|
      text.gsub!(regex, '') if filters.include?(filter)
    end

    text
  end

  def cleanup_logs
    Dir[logs_path.join('*.log')].each { |log| FileUtils.rm(log) }
  end

  def logs_path
    Pathname.new(File.expand_path('../apps/log', __dir__))
  end
end

RSpec.configure do |config|
  config.include LogHelpers
end
