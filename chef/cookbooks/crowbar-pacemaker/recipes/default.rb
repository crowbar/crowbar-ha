#
# Cookbook Name:: crowbar-pacemaker
# Recipe:: default
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

# Enforce no-quorum-policy based on the number of members in the clusters
# We know that for 2 members (or 1, where it doesn't matter), the setting
# should be "ignore". If we have more members, then we use the value set in the
# barclamp.
# For details on the different policies, see
# https://www.suse.com/documentation/sle_ha/book_sleha/data/sec_ha_configuration_basics_global.html
cluster_members_nb = CrowbarPacemakerHelper.cluster_nodes(node).length
if cluster_members_nb <= 2
  node.default[:pacemaker][:crm][:no_quorum_policy] = "ignore"
end

include_recipe "crowbar-pacemaker::stonith"

# We let the founder go first, so it can generate the authkey and some other
# initial pacemaker configuration bits; we do it in the first phase of the chef
# run because the non-founder nodes will look in the compile phase for the
# attribute
crowbar_pacemaker_sync_mark "wait-pacemaker_setup" do
  revision node[:pacemaker]["crowbar-revision"]
  # we use a longer timeout because the wait / create are in two different
  # phases, and this wait is fatal in case of errors
  timeout 120
  fatal true
end.run_action(:guess)

include_recipe "pacemaker::default"

# This is not done in the compile phase, because saving the authkey attribute
# is done in a ruby_block
crowbar_pacemaker_sync_mark "create-pacemaker_setup" do
  revision node[:pacemaker]["crowbar-revision"]
end

# if we ever want to not have a hard dependency on openstack here, we can have
# Crowbar set a node[:pacemaker][:resource_agents] attribute based on available
# barclamps, and do:
# node[:pacemaker][:resource_agents].each do |resource_agent|
#   node[:pacemaker][:platform][:resource_packages][resource_agent].each do |pkg|
#     package pkg
#   end
# end
node[:pacemaker][:platform][:resource_packages][:openstack].each do |pkg|
  package pkg
end

if node[:pacemaker][:drbd][:enabled]
  include_recipe "crowbar-pacemaker::drbd"
end

include_recipe "crowbar-pacemaker::haproxy"

include_recipe "crowbar-pacemaker::maintenance-mode"
