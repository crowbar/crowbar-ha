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

# We know that all nodes in the cluster will run the cookbook with the same
# attributes, so every node can configure its per_node STONITH resource. This
# will always work fine: as all nodes need to be up for the proposal to be
# applied, all nodes will be able to configure their own STONITH resource.
node[:pacemaker][:stonith][:per_node][:mode] = "self"

case node[:pacemaker][:stonith][:mode]
when "sbd"
  sbd_devices = nil
  sbd_devices ||= (node[:pacemaker][:stonith][:sbd][:nodes][node[:fqdn]][:devices] rescue nil)
  sbd_devices ||= (node[:pacemaker][:stonith][:sbd][:nodes][node[:hostname]][:devices] rescue nil)

  sbd_devices.each do |sbd_device|
    if File.symlink?(sbd_device)
      sbd_device_simple = File.expand_path(File.readlink(sbd_device), File.dirname(sbd_device))
    else
      sbd_device_simple = sbd_device
    end
    disks = BarclampLibrary::Barclamp::Inventory::Disk.all(node).select {|d| d.name == sbd_device_simple}
    disk = disks.first
    if disk.nil?
      # This is not a disk; let's see if this is a partition and deal with it
      sbd_sys_dir = "/sys/class/block/#{File.basename(sbd_device_simple)}"
      if File.exists?("#{sbd_sys_dir}/partition") && File.symlink?(sbd_sys_dir)
        sbd_sys_dir_full = File.expand_path(File.readlink(sbd_sys_dir), File.dirname(sbd_sys_dir))
        # sbd_sys_dir_full is something like
        # "/sys/devices/platform/host3/session2/target3:0:0/3:0:0:0/block/sda/sda1",
        # and we want to get the "sda" part of this
        parent_sys_dir_full = sbd_sys_dir_full[1..sbd_sys_dir_full.rindex("/")-1]
        parent_disk = "/dev/#{File.basename(parent_sys_dir_full)}"
        disks = BarclampLibrary::Barclamp::Inventory::Disk.all(node).select {|d| d.name == parent_disk}
        disk = disks.first
      end
    end
    if disk.nil?
      raise "Cannot find device #{sbd_device}!"
    end
    if disk.claimed? && disk.owner != "sbd"
      raise "Cannot use #{sbd_device} for SBD: it was claimed for #{disk.owner}!"
    end
    unless disk.claim("sbd")
      raise "Cannot claim #{sbd_device} for SBD!"
    end
  end

# Need to add the hostlist param for shared
when "shared"
  params = node[:pacemaker][:stonith][:shared][:params]

  if params.respond_to?('to_hash')
    params = params.to_hash
  elsif params.is_a?(String)
    params = ::Pacemaker::Resource.extract_hash(" params #{params}", "params")
  else
    message = "Unknown format for STONITH shared parameters: #{params.inspect}."
    Chef::Log.fatal(message)
    raise message
  end

  member_names = CrowbarPacemakerHelper.cluster_nodes(node).map { |n| n.name }
  params["hostlist"] = member_names.join(" ")

  node.default[:pacemaker][:stonith][:shared][:params] = params

# Crowbar is using FQDN, but crm seems to only know about the hostname without
# the domain, so we need to translate this here
when "per_node"
  nodes = node.default[:pacemaker][:stonith][:per_node][:nodes]
  new_nodes = {}
  domain = node[:domain]

  nodes.keys.each do |fqdn|
    hostname = fqdn.chomp(".#{domain}")
    new_nodes[hostname] = nodes[fqdn].to_hash
  end

  node.default[:pacemaker][:stonith][:per_node][:nodes] = new_nodes

# Translate IPMI stonith mode from the barclamp into something that can be
# understood from the pacemaker cookbook
when "ipmi_barclamp"
  node.default[:pacemaker][:stonith][:mode] = "per_node"
  node.default[:pacemaker][:stonith][:per_node][:agent] = "external/ipmi"
  node.default[:pacemaker][:stonith][:per_node][:nodes] = {}

  CrowbarPacemakerHelper.cluster_nodes(node).each do |cluster_node|
    unless cluster_node.has_key?("ipmi") && cluster_node[:ipmi][:bmc_enable]
      message = "Node #{cluster_node[:hostname]} has no IPMI configuration from IPMI barclamp; another STONITH method must be used."
      Chef::Log.fatal(message)
      raise message
    end

    params = {}
    params["hostname"] = cluster_node[:hostname]
    params["ipaddr"] = cluster_node[:crowbar][:network][:bmc][:address]
    params["userid"] = cluster_node[:ipmi][:bmc_user]
    params["passwd"] = cluster_node[:ipmi][:bmc_password]

    node.default[:pacemaker][:stonith][:per_node][:nodes][cluster_node[:hostname]] ||= {}
    node.default[:pacemaker][:stonith][:per_node][:nodes][cluster_node[:hostname]][:params] = params
  end

# Similarly with the libvirt stonith mode from the barclamp.
when "libvirt"
  node.default[:pacemaker][:stonith][:mode] = "per_node"
  node.default[:pacemaker][:stonith][:per_node][:agent] = "external/libvirt"
  node.default[:pacemaker][:stonith][:per_node][:nodes] = {}

  hypervisor_ip = node[:pacemaker][:stonith][:libvirt][:hypervisor_ip]
  hypervisor_uri = "qemu+tcp://#{hypervisor_ip}/system"

  CrowbarPacemakerHelper.cluster_nodes(node).each do |cluster_node|
    unless %w(Bochs QEMU).include? cluster_node[:dmi][:system][:manufacturer]
      message = "Node #{cluster_node[:hostname]} does not seem to be running in libvirt."
      Chef::Log.fatal(message)
      raise message
    end

    # We need to know the domain to interact with for each cluster member; it
    # turns out that libvirt puts the domain UUID in DMI
    domain_id = cluster_node[:dmi][:system][:uuid]

    params = {}
    params["hostlist"] = "#{cluster_node[:hostname]}:#{domain_id}"
    params["hypervisor_uri"] = hypervisor_uri

    node.default[:pacemaker][:stonith][:per_node][:nodes][cluster_node[:hostname]] ||= {}
    node.default[:pacemaker][:stonith][:per_node][:nodes][cluster_node[:hostname]][:params] = params
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
