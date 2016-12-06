#
# Cookbook Name:: crowbar-pacemaker
# Recipe:: stonith
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

def pacemaker_node_name(n)
  if n[:pacemaker][:is_remote]
    "remote-#{n[:hostname]}"
  else
    n[:hostname]
  end
end

# We know that all nodes in the cluster will run the cookbook with the same
# attributes, so every node can configure its per_node STONITH resource. This
# will always work fine: as all nodes need to be up for the proposal to be
# applied, all nodes will be able to configure their own STONITH resource.
#
# The only exception is the remote nodes, which can't setup resources. So we
# kindly ask the founder node to deal with configuring their STONITH resources.
if CrowbarPacemakerHelper.is_cluster_founder?(node)
  node_list = [pacemaker_node_name(node)]
  remotes = CrowbarPacemakerHelper.remote_nodes(node).map { |n| pacemaker_node_name(n) }
  node_list.concat(remotes)

  node[:pacemaker][:stonith][:per_node][:mode] = "list"
  node[:pacemaker][:stonith][:per_node][:list] = node_list
else
  node[:pacemaker][:stonith][:per_node][:mode] = "self"
end

case node[:pacemaker][:stonith][:mode]
when "sbd"
  include_recipe "crowbar-pacemaker::sbd"
when "shared"
  # Nothing to do, translation done in the rails app
when "per_node"
  # Nothing to do, translation done in the rails app
when "ipmi_barclamp"
  # Nothing to do, translation done in the rails app
when "libvirt"
  # Translation done in the rails app, but check connectivity to libvirtd
  hypervisor_ip = node[:pacemaker][:stonith][:libvirt][:hypervisor_ip]
  hypervisor_uri = "qemu+tcp://#{hypervisor_ip}/system"

  # The agent requires virsh
  package "libvirt-client"

  execute "test if libvirt connection is working for STONITH" do
    user "root"
    command "nc -w 3 #{hypervisor_ip} 16509 < /dev/null && virsh --connect=#{hypervisor_uri} hostname &> /dev/null"
    action :run
  end
end
