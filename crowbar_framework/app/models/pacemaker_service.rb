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
        "pacemaker-cluster-member" => {
          "unique" => false,
          "count" => 32
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

    # elect a founder
    members = role.override_attributes[@bc_name]["elements"]["pacemaker-cluster-member"]
    unless members.nil?
      member_nodes = members.map {|n| NodeObject.find_node_by_name n}

      founder = nil

      # try to re-use founder that was part of old role, or if missing, another
      # node part of the old role (since it's already part of the pacemaker
      # cluster)
      unless old_role.nil?
        old_members = old_role.override_attributes[@bc_name]["elements"]["pacemaker-cluster-member"]
        old_members = old_members.select {|n| members.include? n}
        old_nodes = old_members.map {|n| NodeObject.find_node_by_name n}
        old_nodes.each do |old_node|
          if (old_node[:pacemaker][:founder] rescue false) == true
            founder = old_node
            break
          end
        end

        # the founder from the old role is not there anymore; let's promote
        # another node to founder, so we get the same authkey
        if founder.nil?
          founder = old_nodes.first
        end
      end

      # Still nothing, there are two options:
      #  - there was nothing in common with the old role (we will want to just
      #    take one node)
      #  - the proposal was deactivated (but we still had a founder before that
      #    we want to keep)
      if founder.nil?
        member_nodes.each do |member_node|
          if (member_node[:pacemaker][:founder] rescue false) == true
            founder = member_node
            break
          end
        end
      end

      # nothing worked; just take the first node as founder
      if founder.nil?
        founder = member_nodes.first
      end

      member_nodes.each do |member_node|
        member_node[:pacemaker] ||= {}
        is_founder = (member_node.name == founder.name)
        if is_founder != member_node[:pacemaker][:founder]
          member_node[:pacemaker][:founder] = is_founder
          member_node.save
        end
      end
    end

    # set corosync attributes based on what we got in the proposal
    admin_net = ProposalObject.find_data_bag_item "crowbar/admin_network"

    role.default_attributes["corosync"] ||= {}
    role.default_attributes["corosync"]["bind_addr"] = admin_net["network"]["subnet"]

    role.default_attributes["corosync"]["mcast_addr"] = role.default_attributes["pacemaker"]["corosync"]["mcast_addr"]
    role.default_attributes["corosync"]["mcast_port"] = role.default_attributes["pacemaker"]["corosync"]["mcast_port"]

    case role.default_attributes["pacemaker"]["corosync"]["require_clean_for_autostart_wrapper"]
    when "auto"
      role.default_attributes["corosync"]["require_clean_for_autostart"] = (members.length == 2)
    when "true"
      role.default_attributes["corosync"]["require_clean_for_autostart"] = true
    when "false"
      role.default_attributes["corosync"]["require_clean_for_autostart"] = false
    else
      raise "'require_clean_for_autostart_wrapper' value is invalid but passed validation!"
    end

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
    when "sbd"
      nodes = stonith_attributes["sbd"]["nodes"]

      members.each do |member|
        validation_error "Missing SBD devices for node #{member}" unless nodes.has_key?(member)
      end

      sbd_devices_nb = -1
      sbd_devices_mismatch = false
      nodes.keys.each do |node_name|
        if members.include? node_name
          devices = nodes[node_name]["devices"]
          validation_error "Missing SBD devices for node #{node_name}" if devices.empty?

          sbd_devices_nb = devices.length if sbd_devices_nb == -1
          sbd_devices_mismatch = true if devices.length != sbd_devices_nb
        else
          validation_error "SBD devices present for node #{node_name}, while this node is a not a member of the cluster"
        end
      end
      validation_error "All nodes must share the same number of SBD devices (with possibly different paths)" if sbd_devices_mismatch
    when "shared"
      agent = stonith_attributes["shared"]["agent"]
      params = stonith_attributes["shared"]["params"]
      validation_error "Missing fencing agent for shared setup" if agent.blank?
      validation_error "Missing fencing agent parameters for shared setup" if params.blank?
    when "per_node"
      agent = stonith_attributes["per_node"]["agent"]
      nodes = stonith_attributes["per_node"]["nodes"]

      validation_error "Missing fencing agent for per-node setup" if agent.blank?

      members.each do |member|
        validation_error "Missing fencing agent parameters for node #{member}" unless nodes.has_key?(member)
      end

      nodes.keys.each do |node_name|
        if members.include? node_name
          params = nodes[node_name]["params"]
          validation_error "Missing fencing agent parameters for node #{node_name}" if params.blank?
        else
          validation_error "Fencing agent parameters present for node #{node_name}, while this node is a not a member of the cluster"
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
    validate_at_least_n_for_role proposal, "pacemaker-cluster-member", 1

    elements = proposal["deployment"]["pacemaker"]["elements"]

    members = (elements["pacemaker-cluster-member" ] || [])

    if elements.has_key?("hawk-server")
      elements["hawk-server"].each do |n|
        @logger.debug("checking #{n}")
        unless members.include? n
          node = NodeObject.find_node_by_name(n)
          name = node.name
          name = "#{node.alias} (#{name})" if node.alias
          validation_error "Node #{name} has the hawk-server role but not the pacemaker-cluster-member role."
        end
      end
    end

    if proposal["attributes"][@bc_name]["notifications"]["smtp"]["enabled"]
      smtp_settings = proposal["attributes"][@bc_name]["notifications"]["smtp"]
      validation_error "Invalid SMTP server for mail notifications." if smtp_settings["server"].blank?
      validation_error "Invalid sender address for mail notifications." if smtp_settings["from"].blank?
      validation_error "Invalid recipient address for mail notifications." if smtp_settings["to"].blank?
    end

    if proposal["attributes"][@bc_name]["drbd"]["enabled"]
      validation_error "Setting up DRBD requires a cluster of two nodes." if members.length != 2
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

    no_quorum_policy = proposal["attributes"][@bc_name]["crm"]["no_quorum_policy"]
    unless %w(ignore freeze stop suicide).include?(no_quorum_policy)
      validation_error "Invalid no-quorum-policy value: #{no_quorum_policy}."
    end

    stonith_attributes = proposal["attributes"][@bc_name]["stonith"]
    validate_proposal_stonith stonith_attributes, members

    ### Do not allow elements of this proposal to be in another proposal, since
    ### the configuration cannot be shared.
    proposals_raw.each do |p|
      next if p["id"] == proposal["id"]

      (p["deployment"][@bc_name]["elements"]["pacemaker-cluster-member"] || []).each do |other_member|
        if members.include?(other_member)
          p_name = p["id"].gsub("bc-#{@bc_name}-", "")
          validation_error "Nodes cannot be part of multiple Pacemaker proposals, but #{other_member} is already part of proposal \"#{p_name}\"."
        end
      end
    end

    super
  end

end

