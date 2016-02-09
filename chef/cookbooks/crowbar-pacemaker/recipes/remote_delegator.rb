#
# Author:: Adam Spiers
# Cookbook Name:: crowbar-pacemaker
# Recipe:: remote_delegator
#
# Copyright 2015, SUSE
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

# This recipe should be run on the corosync nodes in order to set up
# ocf:pacemaker:remote primitives so that they can control the remote
# nodes via the pacemaker_remote proxy service running on the remote
# nodes.

return unless CrowbarPacemakerHelper.is_cluster_founder?(node)

CrowbarPacemakerHelper.remote_nodes(node, true).each do |remote|
  unless remote[:pacemaker][:remote_setup]
    Chef::Log.info("Skipping creation of remote resource for #{remote[:hostname]} as pacemaker_remote has not been setup yet.")
    next
  end

  params_hash = remote[:pacemaker][:remote][:params].to_hash
  params_hash["server"] = remote[:fqdn]

  pacemaker_primitive "remote-#{remote[:hostname]}" do
    agent remote[:pacemaker][:remote][:agent]
    op remote[:pacemaker][:remote][:op].to_hash
    params params_hash
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  # We use a transaction to avoid creating with target-role=stopped, which
  # results in fencing (pacemaker ensures that the remote node is stopped); and
  # fencing on the primitive creation is quite bad.
  pacemaker_transaction "remote-#{remote[:hostname]}" do
    cib_objects ["pacemaker_primitive[remote-#{remote[:hostname]}]"]
    action :commit_new
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  remote[:pacemaker][:attributes].each do |attr, value|
    execute %(set pacemaker attribute "#{attr}" to "#{value}" on remote #{remote[:hostname]}) do
      command %(crm node attribute remote-#{remote[:hostname]} set "#{attr}" "#{value}")
      # The cluster only does a transition if the attribute value changes,
      # so checking the value before setting would only slow things down
      # for no benefit.
      only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
    end
  end
end
