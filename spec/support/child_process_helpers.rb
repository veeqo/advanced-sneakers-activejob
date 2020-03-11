# frozen_string_literal: true

module ChildProcesseHelpers
  def in_child_process
    read, write = IO.pipe

    pid = fork do
      read.close
      Marshal.dump(yield, write)
      exit!(0)
    end

    write.close
    result = read.read
    Process.wait(pid)
    raise 'child process failed' if result.empty?

    Marshal.load(result)
  end
end

RSpec.configure do |config|
  config.include ChildProcesseHelpers
end
