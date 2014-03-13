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

# Compute no-quorum-policy, based on the number of members in the clusters
# We know that for 2 members (or 1, where it doesn't matter), the setting
# should be "ignore". If we have more members, then we use the default (which
# is "stop").
# For details on the different policies, see
# http://doc.opensuse.org/products/draft/SLE-HA/SLE-ha-guide_sd_draft/cha.ha.configuration.basics.html#sec.ha.configuration.basics.global.quorum
cluster_members_nb = CrowbarPacemakerHelper.cluster_nodes(node).length
if cluster_members_nb <= 2
  node.default[:pacemaker][:crm][:no_quorum_policy] = "ignore"
else
  node.default[:pacemaker][:crm][:no_quorum_policy] = "stop"
end

include_recipe "pacemaker::default"

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

include_recipe "crowbar-pacemaker::haproxy"

include_recipe "crowbar-pacemaker::maintenance-mode"
