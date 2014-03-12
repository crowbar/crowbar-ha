# Copyright 2011, Dell 
# 
# Licensed under the Apache License, Version 2.0 (the "License"); 
# you may not use this file except in compliance with the License. 
# You may obtain a copy of the License at 
# 
#  http://www.apache.org/licenses/LICENSE-2.0 
# 
# Unless required by applicable law or agreed to in writing, software 
# distributed under the License is distributed on an "AS IS" BASIS, 
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
# See the License for the specific language governing permissions and 
# limitations under the License. 
# 

class PacemakerService < ServiceObject

  def initialize(thelogger)
    super(thelogger)
    @bc_name = "pacemaker"
  end

  def self.allow_multiple_proposals?
    true
  end

  class << self
    def role_constraints
      {
        "pacemaker-cluster-founder" => {
          "unique" => false,
          "count" => 1
        },
        "pacemaker-cluster-member" => {
          "unique" => false,
          "count" => 31
        },
        "hawk-server" => {
          "unique" => false,
          "count" => -1
        }
      }
    end
  end

  def create_proposal
    @logger.debug("Pacemaker create_proposal: entering")
    base = super

    used_mcast_addrs = {}

    proposals_raw.each do |p|
      mcast_addr = p["attributes"][@bc_name]["corosync"]["mcast_addr"]
      used_mcast_addrs[mcast_addr] = true
    end
    RoleObject.find_roles_by_name("pacemaker-config-*").each do |r|
      mcast_addr = r.default_attributes["pacemaker"]["corosync"]["mcast_addr"]
      used_mcast_addrs[mcast_addr] = true
    end

    free_mcast_addr_found = false
    (0..255).each do |mcast_third|
      (1..254).each do |mcast_fourth|
        mcast_addr = "239.255.#{mcast_third}.#{mcast_fourth}"
        unless used_mcast_addrs.has_key? mcast_addr
          base["attributes"][@bc_name]["corosync"]["mcast_addr"] = mcast_addr
          free_mcast_addr_found = true
          break
        end
      end
      break if free_mcast_addr_found
    end

    raise "Cannot find an available multicast address!" unless free_mcast_addr_found

    @logger.debug("Pacemaker create_proposal: exiting")
    base
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Pacemaker apply_role_pre_chef_call: entering #{all_nodes.inspect}")

    admin_net = ProposalObject.find_data_bag_item "crowbar/admin_network"

    role.default_attributes["corosync"] ||= {}
    role.default_attributes["corosync"]["bind_addr"] = admin_net["network"]["subnet"]

    role.default_attributes["corosync"]["mcast_addr"] = role.default_attributes["pacemaker"]["corosync"]["mcast_addr"]
    role.default_attributes["corosync"]["mcast_port"] = role.default_attributes["pacemaker"]["corosync"]["mcast_port"]

    unless role.default_attributes["pacemaker"]["corosync"]["password"].empty?
      if old_role
        old_role_password = old_role.default_attributes["pacemaker"]["corosync"]["password"]
      else
        old_role_password = nil
      end

      role_password = role.default_attributes["pacemaker"]["corosync"]["password"]

      if old_role && role_password == old_role_password
        role.default_attributes["corosync"]["password"] = old_role.default_attributes["corosync"]["password"]
      else
        role.default_attributes["corosync"]["password"] = %x[openssl passwd -1 "#{role_password}" | tr -d "\n"]
      end
    end

    role.save

    @logger.debug("Pacemaker apply_role_pre_chef_call: leaving")
  end

  def apply_role_post_chef_call(old_role, role, all_nodes)
    @logger.debug("Pacemaker apply_role_post_chef_call: entering #{all_nodes.inspect}")

    # Make sure the nodes have a link to the dashboard on them.  This
    # needs to be done via apply_role_post_chef_call rather than
    # apply_role_pre_chef_call, since the server port attribute is not
    # available until chef-client has run.
    all_nodes.each do |n|
      node = NodeObject.find_node_by_name(n)

      next unless node.role? "hawk-server"

      hawk_server_ip = node.get_network_by_type("admin")["address"]
      hawk_server_port = node["hawk"]["server"]["port"]
      url = "https://#{hawk_server_ip}:#{hawk_server_port}/"

      node.crowbar["crowbar"] = {} if node.crowbar["crowbar"].nil?
      node.crowbar["crowbar"]["links"] = {} if node.crowbar["crowbar"]["links"].nil?
      node.crowbar["crowbar"]["links"]["Pacemaker Cluster (Hawk)"] = url
      node.save
    end

    @logger.debug("Pacemaker apply_role_post_chef_call: leaving")
  end

  def validate_proposal_stonith stonith_attributes, members
    case stonith_attributes["mode"]
    when "manual"
      # nothing to do
    when "clone"
      plugin = stonith_attributes["clone"]["plugin"]
      params = stonith_attributes["clone"]["params"]
      validation_error "Missing STONITH plugin for clone setup" if plugin.blank?
      validation_error "Missing STONITH parameters for clone setup" if params.blank?
    when "per_node"
      plugin = stonith_attributes["per_node"]["plugin"]
      nodes = stonith_attributes["per_node"]["nodes"]

      validation_error "Missing STONITH plugin for per-node setup" if plugin.blank?

      members.each do |member|
        validation_error "Missing STONITH parameters for node #{member}" unless nodes.has_key?(member)
      end

      nodes.keys.each do |node_name|
        if members.include? node_name
          params = nodes[node_name]["params"]
          validation_error "Missing STONITH parameters for node #{node_name}" if params.blank?
        else
          validation_error "STONITH parameters for node #{node_name}, while this node is a not a member of the cluster"
        end
      end
    when "ipmi_barclamp"
      members.each do |member|
        node = NodeObject.find_node_by_name(member)
        unless !node[:ipmi].nil? && node[:ipmi][:bmc_enable]
          validation_error "Automatic IPMI setup not available for node #{member}"
        end
      end
    when "libvirt"
      hypervisor_ip = stonith_attributes["libvirt"]["hypervisor_ip"]
      # FIXME: we really need to have crowbar provide a helper to validate IP addresses
      if hypervisor_ip.blank? || hypervisor_ip =~ /[^\.0-9]/
        validation_error "Hypervisor IP \"#{hypervisor_ip}\" is invalid."
      end
      members.each do |member|
        node = NodeObject.find_node_by_name(member)
        unless node[:dmi][:system][:manufacturer] == "Bochs"
          validation_error "Node  #{member} does not seem to be running in libvirt."
        end
      end
    else
      validation_error "Unknown STONITH mode: #{stonith_attributes["mode"]}."
    end
  end

  def validate_proposal_after_save proposal
    validate_one_for_role proposal, "pacemaker-cluster-founder"

    elements = proposal["deployment"]["pacemaker"]["elements"]

    @logger.debug("Pacemaker apply_role_pre_chef_call: elts #{elements.inspect}")
    members = (elements["pacemaker-cluster-founder"] || []) +
              (elements["pacemaker-cluster-member" ] || [])
    @logger.debug("cluster members: #{members}")

    if elements.has_key?("hawk-server")
      elements["hawk-server"].each do |n|
        @logger.debug("checking #{n}")
        unless members.include? n
          node = NodeObject.find_node_by_name(n)
          name = node.name
          name = "#{node.alias} (#{name})" if node.alias
          validation_error "Node #{name} has the hawk-server role but not either the pacemaker-cluster-founder or pacemaker-cluster-member role."
        end
      end
    end

    nodes = NodeObject.find("roles:provisioner-server")
    unless nodes.nil? or nodes.length < 1
      provisioner_server_node = nodes[0]
      if provisioner_server_node[:platform] == "suse"
        if (provisioner_server_node[:provisioner][:suse][:missing_hae] rescue true)
          validation_error "The HAE repositories have not been setup."
        end
      end
    end

    stonith_attributes = proposal["attributes"][@bc_name]["stonith"]
    validate_proposal_stonith stonith_attributes, members

    super
  end

end

