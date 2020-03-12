# frozen_string_literal: true

require 'sourcify'

# Runs separate ruby process and sends code snippet to it.
# Expects app to evaluate the code and return marshalized result in STDOUT. Logs are expected to be written to STDERR
module ChildProcessHelpers
  def in_child_process(name, env: {}, &block)
    input_reader, input_writer = IO.pipe
    output_reader, output_writer = IO.pipe
    err_reader, err_writer = IO.pipe

    run_separate_process(name: name, read: input_reader, write: output_writer, err: err_writer, env: env)

    input_writer.write block.to_source(strip_enclosure: true) # Sending code block to separate process
    input_writer.close # At this point child process starts to evaluate input
    input_reader.close

    # At this point child process is expected to exit
    output_writer.close
    err_writer.close

    result = begin
      data = output_reader.read

      data.empty? ? data : Marshal.load(data)
             rescue TypeError
               # somebody writes to STDOUT? puts?
               data
    end

    errors = err_reader.read

    output_reader.close
    err_reader.close

    [result, errors]
  end

  def run_separate_process(name:, read:, write:, err:, env:)
    app_path = Pathname.new(File.expand_path('../apps', __dir__)).join(name)
    Process.spawn(env, "ruby -r #{app_path}.rb -e 'Marshal.dump(eval(STDIN.read), STDOUT)'", in: read, out: write, err: err)
  end

  def start_sneakers_consumers(name)
    in_child_process(name) do
      require 'rake'
      require 'sneakers/tasks'
      Rake::Task['sneakers:run'].invoke
    end
  end

  def stop_sneakers_consumers
    return unless File.exist?('sneakers.pid')

    Process.kill('TERM', File.open('sneakers.pid').read.to_i)
    FileUtils.rm('sneakers.pid')
  end
end

RSpec.configure do |config|
  config.include ChildProcessHelpers
  config.after(:each) do
    stop_sneakers_consumers # ensure consumers stopped even if tests are failing
  end
end
