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
        # This is informational only, and gives us a fraction more
        # information in /var/log/chef/client.log and in the default
        # attributes (until next run) for debugging purposes.
        # However, it will only take effect after the handler has been
        # installed in /etc/chef/client.rb *and* chef-client daemon
        # has subsequently been restarted; the
        # reload_chef_client_config hack doesn't work with
        # start_handlers since it reloads the config too late, after
        # the start handlers have already been triggered.
        start_mode = record_maintenance_mode_before_this_chef_run
        Chef::Log.info("Pacemaker maintenance mode currently %s" %
                       [start_mode ? "on" : "off"])

        if maintenance_mode_set_via_this_chef_run?
          # Sanity check: this should never happen because we're using
          # default attributes which get wiped for each chef-client run.
          raise "BUG: Pacemaker maintenance mode was already set at the start of this run! (pid #$$)"
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
            system("crm --wait node ready #{pacemaker_node_name}")
          else
            # This shouldn't happen, and suggests that one of the recipes
            # is interfering in a way it shouldn't.
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
