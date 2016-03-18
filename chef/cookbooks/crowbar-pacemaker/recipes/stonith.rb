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

# Need to add the hostlist param for shared
when "shared"
  params = node[:pacemaker][:stonith][:shared][:params]

  if params.respond_to?("to_hash")
    params = params.to_hash
  elsif params.is_a?(String)
    params = ::Pacemaker::Resource.extract_hash(" params #{params}", "params")
  else
    message = "Unknown format for STONITH shared parameters: #{params.inspect}."
    Chef::Log.fatal(message)
    raise message
  end

  all_nodes = CrowbarPacemakerHelper.cluster_nodes(node) + \
    CrowbarPacemakerHelper.remote_nodes(node)

  member_names = all_nodes.map { |n| pacemaker_node_name(n) }
  params["hostlist"] = member_names.join(" ")

  node.default[:pacemaker][:stonith][:shared][:params] = params

# Crowbar is using FQDN, but pacemaker seems to only know about the hostname
# without the domain (and hostnames for remote nodes are not real "hostnames",
# but primitive names), so we need to translate this here
when "per_node"
  nodes = node.default[:pacemaker][:stonith][:per_node][:nodes]
  new_nodes = {}
  domain = node[:domain]

  all_nodes = CrowbarPacemakerHelper.cluster_nodes(node) + \
    CrowbarPacemakerHelper.remote_nodes(node)

  nodes.keys.each do |fqdn|
    cluster_node = all_nodes.find { |n| fqdn == n[:fqdn] }
    next if cluster_node.nil?

    stonith_node_name = pacemaker_node_name(cluster_node)
    new_nodes[stonith_node_name] = nodes[fqdn].to_hash
  end

  node.default[:pacemaker][:stonith][:per_node][:nodes] = new_nodes

# Translate IPMI stonith mode from the barclamp into something that can be
# understood from the pacemaker cookbook
when "ipmi_barclamp"
  node.default[:pacemaker][:stonith][:mode] = "per_node"
  node.default[:pacemaker][:stonith][:per_node][:agent] = "external/ipmi"
  node.default[:pacemaker][:stonith][:per_node][:nodes] = {}

  all_nodes = CrowbarPacemakerHelper.cluster_nodes(node) + \
    CrowbarPacemakerHelper.remote_nodes(node)

  all_nodes.each do |cluster_node|
    unless cluster_node.key?("ipmi") && cluster_node[:ipmi][:bmc_enable]
      message = "Node #{cluster_node[:hostname]} has no IPMI configuration from IPMI barclamp; another STONITH method must be used."
      Chef::Log.fatal(message)
      raise message
    end

    stonith_node_name = pacemaker_node_name(cluster_node)

    params = {}
    params["hostname"] = stonith_node_name
    params["ipaddr"] = cluster_node[:crowbar][:network][:bmc][:address]
    params["userid"] = cluster_node[:ipmi][:bmc_user]
    params["passwd"] = cluster_node[:ipmi][:bmc_password]

    node.default[:pacemaker][:stonith][:per_node][:nodes][stonith_node_name] ||= {}
    node.default[:pacemaker][:stonith][:per_node][:nodes][stonith_node_name][:params] = params
  end

# Similarly with the libvirt stonith mode from the barclamp.
when "libvirt"
  node.default[:pacemaker][:stonith][:mode] = "per_node"
  node.default[:pacemaker][:stonith][:per_node][:agent] = "external/libvirt"
  node.default[:pacemaker][:stonith][:per_node][:nodes] = {}

  hypervisor_ip = node[:pacemaker][:stonith][:libvirt][:hypervisor_ip]
  hypervisor_uri = "qemu+tcp://#{hypervisor_ip}/system"

  all_nodes = CrowbarPacemakerHelper.cluster_nodes(node) + \
    CrowbarPacemakerHelper.remote_nodes(node)

  all_nodes.each do |cluster_node|
    manufacturer = cluster_node[:dmi][:system][:manufacturer] rescue "unknown"
    unless %w(Bochs QEMU).include? manufacturer
      message = "Node #{cluster_node[:hostname]} does not seem to be running in libvirt."
      Chef::Log.fatal(message)
      raise message
    end

    # We need to know the domain to interact with for each cluster member; it
    # turns out that libvirt puts the domain UUID in DMI
    domain_id = cluster_node[:dmi][:system][:uuid]

    stonith_node_name = pacemaker_node_name(cluster_node)

    params = {}
    params["hostlist"] = "#{stonith_node_name}:#{domain_id}"
    params["hypervisor_uri"] = hypervisor_uri

    node.default[:pacemaker][:stonith][:per_node][:nodes][stonith_node_name] ||= {}
    node.default[:pacemaker][:stonith][:per_node][:nodes][stonith_node_name][:params] = params
  end

  # The agent requires virsh
  package "libvirt-client"

  # validate that the IP address looks a minimum like an IP address, to avoid
  # command injection
  # FIXME: we really need a helper to validate IP addresses; it's not critical
  # here, though as the later test will fail if the IP address is not valid
  if hypervisor_ip =~ /[^\.0-9]/
    message = "Hypervisor IP \"#{hypervisor_ip}\" is invalid."
    Chef::Log.fatal(message)
    raise message
  end

  execute "test if libvirt connection is working for STONITH" do
    user "root"
    command "nc -w 3 #{hypervisor_ip} 16509 < /dev/null && virsh --connect=#{hypervisor_uri} hostname &> /dev/null"
    action :run
  end
end
