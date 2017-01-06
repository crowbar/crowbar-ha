#
# Author:: Adam Spiers
# Cookbook Name:: crowbar-pacemaker
# Recipe:: remote
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

# The parent recipe to be run on all remote nodes.
node.set[:pacemaker][:is_remote] = true

# Figure out which cluster we're tied to, so that we can find the founder
# and hence the authkey.
node[:corosync][:cluster_name] = CrowbarPacemakerHelper.cluster_name(node)

if node[:pacemaker][:stonith][:mode] == "sbd"
  include_recipe "crowbar-pacemaker::sbd"

  stonith_node_name = "remote-#{node[:hostname]}"
  if node[:pacemaker][:stonith][:sbd][:nodes][node[:fqdn]][:slot_name] != stonith_node_name
    node[:pacemaker][:stonith][:sbd][:nodes][node[:fqdn]][:slot_name] = stonith_node_name
    node.save
  end
end

include_recipe "crowbar-pacemaker::pacemaker_authkey"
include_recipe "pacemaker::remote"

ruby_block "mark node as ready for pacemaker_remote" do
  block do
    node[:pacemaker][:remote_setup] = true
    node.save
  end
end

include_recipe "crowbar-pacemaker::openstack"
