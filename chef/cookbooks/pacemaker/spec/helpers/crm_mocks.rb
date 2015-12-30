require_relative "shellout"

class Chef
  module RSpec
    module Pacemaker
      module Mocks
        include Chef::RSpec::Mixlib::ShellOut

        def show_cib_object_command(name)
          "crm --display=plain configure show #{name}"
        end

        # For example, "crm configure show" is executed by
        # #load_current_resource, and again later on for the :create
        # action, to see whether to create or modify.  So the first
        # double in the sequence would return an empty definition if we
        # wanted to test creation of a new CIB object, or an existing
        # definition if we wanted to test modification of an existing
        # one.  If the test needs subsequent doubles to return different
        # values then stdout_strings can have more than one element.

        # Return a Mixlib::ShellOut double which mimics failed
        # execution of a command, raising an exception when #error! is
        # called.  We expect #error! to be called, because if it isn't,
        # that probably indicates the code isn't robust enough.  This
        # may need to be relaxed in the future.
        def existing_cib_object_opts(name, definition)
          {
            command: show_cib_object_command(name),
            stdout: definition
          }
        end

        def nonexistent_cib_object_opts(name)
          {
            command: show_cib_object_command(name),
            stderr: format("ERROR: object %s does not exist", name),
            exitstatus: 1
          }
        end

        def existing_cib_object_double(name, definition)
          shellout_double(existing_cib_object_opts(name, definition))
        end

        def nonexistent_cib_object_double(name)
          shellout_double(nonexistent_cib_object_opts(name))
        end

        def mock_existing_cib_object(name, definition)
          stub_shellout(existing_cib_object_opts(name, definition))
        end

        def mock_existing_cib_object_from_fixture(fixture)
          mock_existing_cib_object(fixture.name, fixture.definition)
        end

        def mock_nonexistent_cib_object(name)
          stub_shellout(nonexistent_cib_object_opts(name))
        end
      end
    end
  end
end
