# frozen_string_literal: true

module IRB
  # The implementation of this class is borrowed from RDoc's lib/rdoc/ri/driver.rb.
  # Please do NOT use this class directly outside of IRB.
  class Pager
    PAGE_COMMANDS = [ENV['RI_PAGER'], ENV['PAGER'], 'less', 'more'].compact.uniq

    class << self
      def page
        if STDIN.tty? && pager = setup_pager
          begin
            pid = pager.pid
            yield pager
          ensure
            pager.close
          end
        else
          yield $stdout
        end
      # When user presses Ctrl-C, IRB would raise `IRB::Abort`
      # But since Pager is implemented by running paging commands like `less` in another process with `IO.popen`,
      # the `IRB::Abort` exception only interrupts IRB's execution but doesn't affect the pager
      # So to properly terminate the pager with Ctrl-C, we need to catch `IRB::Abort` and kill the pager process
      rescue IRB::Abort
        Process.kill("TERM", pid) if pid
        nil
      rescue Errno::EPIPE
      end

      private

      def setup_pager
        require 'shellwords'

        PAGE_COMMANDS.each do |pager|
          pager = Shellwords.split(pager)
          next if pager.empty?

          if pager.first == 'less' || pager.first == 'more'
            pager << '-R' unless pager.include?('-R')
          end

          begin
            io = IO.popen(pager, 'w')
          rescue
            next
          end

          if $? && $?.pid == io.pid && $?.exited? # pager didn't work
            next
          end

          return io
        end

        nil
      end
    end
  end
end
