#
# Copyright 2014, SUSE
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module CrowbarPacemaker
  # A mixin for Chef::Pacemaker::Handler subclasses, and also for the
  # Chef::Provider::PacemakerService LWRP.
  module MaintenanceModeHelpers
    def cluster_up?
      # For once, we want 2>&1 to come before >/dev/null, not after!
      # This is because we want to capture STDERR and ditch STDOUT.
      cibadmin = `cibadmin -Ql 2>&1 >/dev/null`
      case cibadmin
      when /Connection refused/, /Transport endpoint is not connected/
        Chef::Log.warn("Cluster is down")
        return false
      when /command not found/
        Chef::Log.warn("cibadmin not found; was pacemaker deinstalled?")
        return false
      end

      if !$?.success?
        Chef::Log.warn("cibadmin -Ql failed when checking Pacemaker maintenance mode!")
        Chef::Log.warn(cibadmin)
        return nil # unknown
      end

      Chef::Log.debug("Cluster is up")
      true
    end

    def maintenance_mode?
      case cluster_up?
      when nil # unknown
        Chef::Log.warn("Something wrong, so treating as if in maintenance " +
          "mode; will need manual intervention.")
        return true
      when false
        # Cluster is not up, so let things proceed so that Chef can
        # start it if appropriate.
        Chef::Log.info("Cluster is down; not in maintenance mode")
        return false
      end

      Chef::Log.debug("Checking maintenance mode status")
      # See https://bugzilla.suse.com/show_bug.cgi?id=870696
      `crm_attribute -G -N #{node.hostname} -n maintenance -q` =~ /^on$/
    end

    def set_maintenance_mode_via_this_chef_run
      # We track whether anything has put the node into Pacemaker
      # maintenance mode during this chef-client run, so we know
      # whether to take it out of maintenance mode again at the end of
      # the run without interfering with external influences which
      # might set it.
      #
      # We use a default attribute so that it will get reset at the
      # beginning of each chef-client run.
      node.default[:pacemaker][:maintenance_mode][$PID][:via_chef] = true
    end

    def maintenance_mode_set_via_this_chef_run?
      # The "== true" is required because Chef::Node::Attribute does
      # auto-vivification on read (!), so the value will be initialized
      # to an empty Chef::Node::Attribute if not already set to true.
      node.default[:pacemaker][:maintenance_mode][$PID][:via_chef] == true
    end
  end
end
