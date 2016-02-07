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
    def maintenance_mode?
      # See https://bugzilla.suse.com/show_bug.cgi?id=870696
      !! (`crm_attribute -G -N #{node.hostname} -n maintenance -d off -q` =~ /^on$/)
    end

    def record_maintenance_mode_before_this_chef_run
      # Via Chef::Pacemaker::StartHandler we track whether anything
      # has put the node into Pacemaker maintenance mode prior to this
      # chef-client run.  This may come in handy during debugging.
      #
      # We use a default attribute so that it will get reset at the
      # beginning of each chef-client run.
      node.default[:pacemaker][:maintenance_mode][$$][:at_start] = maintenance_mode?
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
      node.default[:pacemaker][:maintenance_mode][$$][:via_chef] = true
    end

    def maintenance_mode_set_via_this_chef_run?
      # The "== true" is required because Chef::Node::Attribute does
      # auto-vivification on read (!), so the value will be initialized
      # to an empty Chef::Node::Attribute if not already set to true.
      node.default[:pacemaker][:maintenance_mode][$$][:via_chef] == true
    end
  end
end
