#
# Cookbook Name:: crowbar-pacemaker
# Recipe:: pacemaker_authkey
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

# This recipe is intended for use on *all* cluster nodes, i.e. both
# corosync and remote nodes.  Only the founder generates an authkey
# for communication with remote nodes, and all the others copy it;
# thefore it must be run on the corosync nodes first.  Crowbar
# achieves this by first running it via the pacemaker-cluster-member
# role, and then later by the pacemaker-remote role.

require "base64"

if Chef::Config[:solo]
  Chef::Application.fatal! "This recipe uses search. Chef Solo does not support search."
  return
end

# FIXME: deduplicate code with corosync::authkey recipe

cluster_name = node[:corosync][:cluster_name]
unless cluster_name && !cluster_name.empty?
  Chef::Application.fatal! "Couldn't figure out corosync cluster name"
  return
end

# Find pre-existing authkey on other node(s)
query  = "chef_environment:#{node.chef_environment}"
query += " AND corosync_cluster_name:#{cluster_name}"

authkey_node = nil

if node[:pacemaker][:founder]
  if node[:pacemaker][:authkey].nil?
    include_recipe "pacemaker::authkey_generator"
  else
    # make sure the authkey stays written
    include_recipe "pacemaker::authkey_writer"
  end
else
  query +=
    " AND pacemaker_founder:true " \
    " AND pacemaker_config_environment:#{node[:pacemaker][:config][:environment]}"
  founder_nodes = search(:node, query)
  raise "No founder node found!" if founder_nodes.length == 0
  raise "Multiple founder nodes found!" if founder_nodes.length > 1
  authkey_node = founder_nodes[0]
end

unless authkey_node.nil?
  log("Using pacemaker authkey from node: #{authkey_node.name}")
  authkey = authkey_node[:pacemaker][:authkey]

  node.set[:pacemaker][:authkey] = authkey
  node.save
  include_recipe "pacemaker::authkey_writer"
end
