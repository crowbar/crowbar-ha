# Ensure that we exit Pacemaker maintenance mode when appropriate.
# See the crowbar-pacemaker::maintenance-mode recipe for more
# information.

# These handlers will be loaded by Chef at startup, via
# /etc/chef/client.rb.  At this point there is no guarantee that
# /var/cache/chef is populated (crowbar_join will wipe the cache
# during boot if its first chef-client run fails), so the
# maintenance-mode recipe ensures that maintenance_mode_helpers.rb is
# permanently installed under /var/chef/libraries at the same time the
# handlers are installed in /etc/chef/client.rb.
require "/var/chef/libraries/maintenance_mode_helpers"

class Chef
  module Pacemaker
    class Handler < Chef::Handler
      include CrowbarPacemaker::MaintenanceModeHelpers
    end

    class StartHandler < Handler
      def report
        # Check we're not in maintenance mode.  This could happen for two
        # reasons:
        #
        #   1. A previous chef-client run failed, so we shouldn't
        #      risk compounding problems by trying again until the
        #      root cause is addressed.
        #
        #   2. Someone/something other than Chef set the node into
        #      maintenance mode.  That should be rare, but when it
        #      happens, we shouldn't interfere.
        #
        # So in both cases, we should abort the run immediately with a
        # helpful message.
        if maintenance_mode?
          raise \
            "Pacemaker maintenance mode was already set on " \
            "#{node.hostname}; aborting! Please diagnose why this was the " \
            "case, fix the root cause, and then unset maintenance mode via " \
            "HAWK or by running 'crm node ready' on the node."
        end
      end
    end

    class ReportHandler < Handler
      def report
        if maintenance_mode_set_via_this_chef_run?
          # Chef::Provider::PacemakerService must have handled at
          # least one :restart action, so we know we need to take
          # the node out of maintenance mode.

          if maintenance_mode?
            Chef::Log.info("Taking node out of Pacemaker maintenance mode")
            system("crm --wait node ready")
          else
            # This shouldn't happen, and suggests that something is
            # interfering in a way it shouldn't.
            raise "Something took node out of maintenance mode during run!"
          end
        else
          if maintenance_mode?
            Chef::Log.warn("Node placed in Pacemaker maintenance mode but " +
                           "not by Chef::Provider::PacemakerService; leaving as is")
          else
            Chef::Log.debug("Node not in Pacemaker maintenance mode")
          end
        end
      end
    end

    class ExceptionHandler < Handler
      def report
        if maintenance_mode_set_via_this_chef_run?
          Chef::Log.warn("chef-client run failed; leaving node in Pacemaker maintenance mode")
          Chef::Log.warn("Manual clean-up required!  (Finish via 'crm node ready'.)")
        end
      end
    end
  end
end
