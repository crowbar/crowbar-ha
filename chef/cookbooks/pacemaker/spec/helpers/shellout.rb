require "mixlib/shellout"

module Chef::RSpec
  module Mixlib
    module ShellOut
      # Stubs Mixlib::ShellOut.new to return a double mimicking the
      # behaviour of Mixlib::ShellOut being used to run a real
      # command.  This allows us to simulate a shell command being run
      # via Mixlib::ShellOut.  The arguments are passed to
      # #shellout_double.
      def stub_shellout(opts)
        double = shellout_double(opts)
        expect(::Mixlib::ShellOut).
          to receive(:new).with(opts[:command]).and_return(double)
        # puts "expecting [#{opts[:command]}]"
        # puts "to yield [#{opts[:stdout]}, #{opts[:stderr]}, #{opts[:exitstatus]}]"
        # puts "double #{double.object_id}"
      end

      # Stubs Mixlib::ShellOut.new to return a sequence of doubles,
      # each mimicking the behaviour of Mixlib::ShellOut being used to
      # run a real command.  This allows us to simulate the output of
      # a series of shell commands being run via Mixlib::ShellOut.
      # Each argument is a Hash containing the options to be passed to
      # #shellout_double which describe the command and the
      # corresponding double which should be returned.
      #
      # FIXME: this usage mode doesn't verify the argument passed to
      # #new, because I couldn't figure out how to do that for
      # multiple return values.
      def stub_shellouts(*sequence)
        expect(::Mixlib::ShellOut).
          to receive(:new).and_return(*sequence)
      end

      # Constructs a Mixlib::ShellOut double for use with
      # #stub_shellout, mimicking execution of the given command, as
      # if it outputted the given strings on STDOUT and STDERR and
      # exited with the given exit code.
      def shellout_double(command:, stdout: "", stderr: "", exitstatus: 0)
        shellout = double(::Mixlib::ShellOut)
        expect(shellout).to receive(:environment).and_return({})
        expect(shellout).to receive(:run_command)
        allow(shellout).to receive(:stdout).and_return(stdout)
        allow(shellout).to receive(:stderr).and_return(stderr)
        allow(shellout).to receive(:exitstatus).and_return(exitstatus)
        if exitstatus == 0
          expect(shellout).to receive(:error!)
        else
          exception = ::Mixlib::ShellOut::ShellCommandFailed.new(
            "Expected process to exit with 0, " \
            "but received '#{exitstatus}'"
          )
          expect(shellout).to receive(:error!).and_raise(exception)
        end
        shellout
      end
    end
  end
end
