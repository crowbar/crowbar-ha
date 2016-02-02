#
# Copyright 2011-2013, Dell
# Copyright 2013-2014, SUSE LINUX Products GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
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
          "count" => 32,
          "platform" => {
            "suse" => "/.*/",
            "opensuse" => "/.*/"
          }
        },
        "hawk-server" => {
          "unique" => false,
          "count" => -1,
          "platform" => {
            "suse" => "/.*/",
            "opensuse" => "/.*/"
          }
        },
        "pacemaker-remote" => {
          "unique" => true,
          "count" => -1,
          "platform" => {
            "suse" => "/.*/",
            "opensuse" => "/.*/"
          }
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
        unless used_mcast_addrs.key? mcast_addr
          base["attributes"][@bc_name]["corosync"]["mcast_addr"] = mcast_addr
          free_mcast_addr_found = true
          break
        end
      end
      break if free_mcast_addr_found
    end

    raise "Cannot find an available multicast address!" unless free_mcast_addr_found

    base["attributes"][@bc_name]["drbd"]["shared_secret"] = random_password

    @logger.debug("Pacemaker create_proposal: exiting")
    base
  end

  # Small helper to get the list of nodes used by a barclamp proposal (applied
  # or not)
  def all_nodes_used_by_barclamp(role)
    role.elements.values.flatten.compact.uniq
  end

  # Small helper to expand all items (nodes, clusters) used inside an applied
  # proposal
  def expand_nodes_in_barclamp_role(cluster_role, node_object_all)
    all_nodes_for_cluster_role = all_nodes_used_by_barclamp(cluster_role)

    all_nodes_for_cluster_role_expanded, failures = expand_nodes_for_all(all_nodes_for_cluster_role)
    unless failures.nil? || failures.empty?
      @logger.warn "[pacemaker] expand_nodes_in_barclamp_role: skipping items that we failed to expand: #{failures.join(", ")}"
    end

    # Do not keep deleted nodes
    all_nodes_for_cluster_role_expanded = all_nodes_for_cluster_role_expanded & node_object_all.map{ |n| n.name }

    all_nodes_for_cluster_role_expanded
  end

  def apply_cluster_roles_to_new_nodes_for(cluster_element, relevant_nodes, all_roles)
    return [] if relevant_nodes.empty?

    ### Beware of possible confusion between different level of "roles"!
    # See comment in apply_cluster_roles_to_new_nodes
    required_barclamp_roles = []
    required_pre_chef_calls = []

    # Find all barclamp roles where this cluster is used
    cluster_roles = all_roles.select do |role_object|
      role_object.proposal? && \
      all_nodes_used_by_barclamp(role_object).include?(cluster_element)
    end

    # Inside each barclamp role, identify which role is required
    for cluster_role in cluster_roles do
      service = ServiceObject.get_service(cluster_role.barclamp).new(Rails.logger)

      deployment = cluster_role.override_attributes[cluster_role.barclamp]
      runlist_priority_map = deployment["element_run_list_order"] || {}
      role_map = deployment["element_states"] || {}

      save_it = false

      cluster_role.elements.each do |role_name, node_names|
        next unless node_names.include?(cluster_element)

        required_barclamp_roles << { service: service,
                                     barclamp_role: cluster_role,
                                     name: role_name,
                                     priority: runlist_priority_map[role_name] || service.chef_order,
                                     element_states: role_map[role_name] }

        # Update elements_expanded attribute
        expanded_nodes, failures = expand_nodes_for_all(node_names)
        unless failures.nil? || failures.empty?
          @logger.warn "[pacemaker] apply_cluster_roles_to_new_nodes: skipping items that we failed to expand: #{failures.join(", ")}"
        end

        expanded_nodes.sort!
        old_expanded_nodes = deployment["elements_expanded"][role_name].sort

        if old_expanded_nodes != expanded_nodes
          deployment["elements_expanded"][role_name] = expanded_nodes
          save_it = true
        end
      end

      # Also add the config role for the barclamp
      required_barclamp_roles << { service: service,
                                   barclamp_role: cluster_role,
                                   name: cluster_role.name,
                                   priority: runlist_priority_map[cluster_role.name] || service.chef_order,
                                   element_states: role_map[cluster_role.name] }

      cluster_role.save if save_it
    end

    # Ensure that all nodes in the cluster have all required roles
    relevant_nodes.each do |node|
      save_it = false

      required_barclamp_roles.each do |required_barclamp_role|
        name = required_barclamp_role[:name]
        next if node.role? name

        priority = required_barclamp_role[:priority]
        element_states = required_barclamp_role[:element_states]

        @logger.debug("[pacemaker] AR: Adding role #{name} to #{node.name} with priority #{priority}")
        node.add_to_run_list(name, priority, element_states)
        save_it = true

        required_pre_chef_calls << { service: required_barclamp_role[:service], barclamp_role: required_barclamp_role[:barclamp_role] }
      end

      node.save if save_it
    end

    required_pre_chef_calls
  end

  def apply_cluster_roles_to_new_nodes(role, member_nodes, remote_nodes)
    ### Beware of possible confusion between different level of "roles"!
    # - we have barclamp roles that are related to a barclamp (as in "knife role
    #   list | grep config" or RoleObject.proposal?); the cluster_role variable
    #   is always such a role
    # - we have roles inside each barclamp roles (as in "the role I assign to
    #   nodes, like provisioner-server")

    # Make sure that all nodes in the cluster have all the roles assigned to
    # this cluster.

    required_pre_chef_calls = []
    all_roles = RoleObject.all

    required_pre_chef_calls.concat(
      apply_cluster_roles_to_new_nodes_for(
        "#{PacemakerServiceObject.cluster_key}:#{role.inst}", member_nodes, all_roles
      )
    )

    required_pre_chef_calls.concat(
      apply_cluster_roles_to_new_nodes_for(
        "#{PacemakerServiceObject.remotes_key}:#{role.inst}", remote_nodes, all_roles
      )
    )

    # Avoid doing this query multiple times
    node_object_all = NodeObject.all

    # For each service where we had to manually update a node for a missing
    # role, we need to call apply_role_pre_chef_call
    required_pre_chef_calls.uniq.each do |required_pre_chef_call|
      cluster_role = required_pre_chef_call[:barclamp_role]
      service = required_pre_chef_call[:service]

      all_nodes_for_cluster_role_expanded = expand_nodes_in_barclamp_role(cluster_role, node_object_all)

      @logger.debug("[pacemaker] Calling apply_role_pre_chef_call for #{service.bc_name}")
      service.apply_role_pre_chef_call(cluster_role, cluster_role, all_nodes_for_cluster_role_expanded)
    end

    role_deployment = role.override_attributes[@bc_name]
    required_post_chef_calls = required_pre_chef_calls.map{ |n| n[:barclamp_role].name }.uniq

    if required_post_chef_calls != role_deployment["required_post_chef_calls"]
      role_deployment["required_post_chef_calls"] = required_post_chef_calls
      role.save
    end
  end

  def apply_cluster_roles_to_new_nodes_post_chef_call(role)
    # Avoid doing this query multiple times
    node_object_all = NodeObject.all

    for cluster_role_name in role.override_attributes[@bc_name]["required_post_chef_calls"] do
      cluster_role = RoleObject.find_role_by_name(cluster_role_name)

      if cluster_role_name.nil?
        @logger.debug("[pacemaker] apply_cluster_roles_to_new_nodes_post_chef_call: Cannot find #{cluster_role_name} role; skipping apply_role_post_chef_call for it")
        next
      end

      service = ServiceObject.get_service(cluster_role.barclamp).new(Rails.logger)

      all_nodes_for_cluster_role_expanded = expand_nodes_in_barclamp_role(cluster_role, node_object_all)

      @logger.debug("[pacemaker] Calling apply_role_post_chef_call for #{service.bc_name}")
      service.apply_role_post_chef_call(cluster_role, cluster_role, all_nodes_for_cluster_role_expanded)
    end
  end

  # Override this so we can change element_order dynamically on apply:
  #  - when there's no remote node, we don't want to run anything twice on
  #    cluster members
  #  - when there are remote nodes, we need to run the delegator code after
  #    setting up the remote nodes, so we need to run chef on cluster members a
  #    second time
  def active_update(proposal, inst, in_queue)
    deployment = proposal["deployment"]["pacemaker"]
    remotes = deployment["elements"]["pacemaker-remote"] || []

    if remotes.empty?
      deployment["element_order"] = [
        ["pacemaker-cluster-member", "hawk-server"],
        ["pacemaker-remote"]
      ]
    else
      deployment["element_order"] = [
        ["pacemaker-cluster-member", "hawk-server"],
        ["pacemaker-remote"],
        ["pacemaker-cluster-member"]
      ]
    end

    # no need to save proposal, it's just data that is passed to later methods
    super
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Pacemaker apply_role_pre_chef_call: entering #{all_nodes.inspect}")

    members = role.override_attributes[@bc_name]["elements"]["pacemaker-cluster-member"] || []
    member_nodes = members.map { |n| NodeObject.find_node_by_name n }
    remotes = role.override_attributes[@bc_name]["elements"]["pacemaker-remote"] || []
    remote_nodes = remotes.map { |n| NodeObject.find_node_by_name n }

    # elect a founder
    unless members.empty?
      founder = nil

      # try to re-use founder that was part of old role, or if missing, another
      # node part of the old role (since it's already part of the pacemaker
      # cluster)
      unless old_role.nil?
        old_members = old_role.override_attributes[@bc_name]["elements"]["pacemaker-cluster-member"]
        old_members = old_members.select { |n| members.include? n }
        old_nodes = old_members.map { |n| NodeObject.find_node_by_name n }
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

      PacemakerServiceObject.reset_sync_marks_on_cluster_founder(founder, role.inst)
    end

    # set corosync attributes based on what we got in the proposal
    admin_net = Chef::DataBag.load("crowbar/admin_network") rescue nil

    role.default_attributes["corosync"] ||= {}
    role.default_attributes["corosync"]["bind_addr"] = admin_net["network"]["subnet"]

    role.default_attributes["corosync"]["mcast_addr"] = role.default_attributes["pacemaker"]["corosync"]["mcast_addr"]
    role.default_attributes["corosync"]["mcast_port"] = role.default_attributes["pacemaker"]["corosync"]["mcast_port"]
    role.default_attributes["corosync"]["members"] = member_nodes.map{ |n| n.get_network_by_type("admin")["address"] }
    role.default_attributes["corosync"]["transport"] = role.default_attributes["pacemaker"]["corosync"]["transport"]

    role.default_attributes["drbd"] ||= {}
    role.default_attributes["drbd"]["common"] ||= {}
    role.default_attributes["drbd"]["common"]["net"] ||= {}
    role.default_attributes["drbd"]["common"]["net"]["shared_secret"] = role.default_attributes["pacemaker"]["drbd"]["shared_secret"]

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

    preserve_existing_password(role, old_role)

    role.save

    apply_cluster_roles_to_new_nodes(role, member_nodes, remote_nodes)

    @logger.debug("Pacemaker apply_role_pre_chef_call: leaving")
  end

  def preserve_existing_password(role, old_role)
    if role.default_attributes["pacemaker"]["corosync"]["password"].empty?
      # no password requested
      return
    end

    old_role_password = old_role ?
        old_role.default_attributes["pacemaker"]["corosync"]["password"]
      : nil

    role_password = role.default_attributes["pacemaker"]["corosync"]["password"]

    role.default_attributes["corosync"]["password"] =
      if old_role &&
          role_password == old_role_password &&
          old_role.default_attributes["corosync"]
        old_role.default_attributes["corosync"]["password"]
      else
        %x[openssl passwd -1 "#{role_password}" | tr -d "\n"]
      end
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

    apply_cluster_roles_to_new_nodes_post_chef_call(role)

    @logger.debug("Pacemaker apply_role_post_chef_call: leaving")
  end

  def validate_proposal_stonith stonith_attributes, members
    case stonith_attributes["mode"]
    when "manual"
      # nothing to do
    when "sbd"
      nodes = stonith_attributes["sbd"]["nodes"]

      members.each do |member|
        validation_error I18n.t(
          "barclamp.#{@bc_name}.validation.missing_sbd_device",
          member: member
        ) unless nodes.key?(member)
      end

      sbd_devices_nb = -1
      sbd_devices_mismatch = false
      nodes.keys.each do |node_name|
        if members.include? node_name
          node_devices = nodes[node_name]["devices"]

          # note that when nothing is defined, we actually have an empty array
          # with an empty string, hence the == 1 test
          unless node_devices.count == 1 || node_devices.select{ |d| d.empty? }.empty?
            validation_error I18n.t(
              "barclamp.#{@bc_name}.validation.empty_sbd_device",
              node_name: node_name
            )
          end

          devices = node_devices.select{ |d| !d.empty? }
          validation_error I18n.t(
            "barclamp.#{@bc_name}.validation.missing_sbd_for_node",
            node_name: node_name
          ) if devices.empty?

          sbd_devices_nb = devices.length if sbd_devices_nb == -1
          sbd_devices_mismatch = true if devices.length != sbd_devices_nb
        else
          validation_error I18n.t(
            "barclamp.#{@bc_name}.validation.node_no_cluster_member",
            node_name: node_name
          )
        end
      end
      validation_error validation_error I18n.t(
        "barclamp.#{@bc_name}.validation.same_number_of_devices"
      ) if sbd_devices_mismatch
    when "shared"
      agent = stonith_attributes["shared"]["agent"]
      params = stonith_attributes["shared"]["params"]
      validation_error I18n.t(
        "barclamp.#{bc_name}.validation.missing_fencing_agent"
      ) if agent.blank?
      validation_error I18n.t(
        "barclamp.#{bc_name}.validation.missing_fencing_agent_params"
      ) if params.blank?
    when "per_node"
      agent = stonith_attributes["per_node"]["agent"]
      nodes = stonith_attributes["per_node"]["nodes"]

      validation_error I18n.t(
        "barclamp.#{bc_name}.validation.missing_fencing_agent_per_node"
      ) if agent.blank?

      members.each do |member|
        validation_error I18n.t(
          "barclamp.#{bc_name}.validation.node_missing_fencing_params",
          member: member
        ) unless nodes.key?(member)
      end

      nodes.keys.each do |node_name|
        if members.include? node_name
          params = nodes[node_name]["params"]
          validation_error I18n.t(
            "barclamp.#{bc_name}.validation.node_missing_fencing_params",
            member: node_name
          ) if params.blank?
        else
          validation_error I18n.t(
            "barclamp.#{bc_name}.validation.fencing_agent_no_cluster",
            node_name: node_name
          )
        end
      end
    when "ipmi_barclamp"
      members.each do |member|
        node = NodeObject.find_node_by_name(member)
        unless !node[:ipmi].nil? && node[:ipmi][:bmc_enable]
          validation_error I18n.t(
            "barclamp.#{bc_name}.validation.automatic_ipmi_setup",
            member: member
          )
        end
      end
    when "libvirt"
      hypervisor_ip = stonith_attributes["libvirt"]["hypervisor_ip"]
      # FIXME: we really need to have crowbar provide a helper to validate IP addresses
      if hypervisor_ip.blank? || hypervisor_ip =~ /[^\.0-9]/
        validation_error I18n.t(
          "barclamp.#{bc_name}.validation.hypervisor_ip",
          hypervisor_ip: hypervisor_ip
        )
      end
      members.each do |member|
        node = NodeObject.find_node_by_name(member)
        manufacturer = node[:dmi][:system][:manufacturer] rescue "unknown"
        unless %w(Bochs QEMU).include? manufacturer
          validation_error I18n.t(
            "barclamp.#{bc_name}.validation.libvirt",
            member: member
          )
        end
      end
    else
      validation_error I18n.t(
        "barclamp.#{bc_name}.validation.stonith_mode",
        stonith_mode: stonith_attributes["mode"]
      )
    end
  end

  def validate_proposal_after_save proposal
    validate_at_least_n_for_role proposal, "pacemaker-cluster-member", 1

    elements = proposal["deployment"]["pacemaker"]["elements"]
    members = elements["pacemaker-cluster-member"] || []
    remotes = elements["pacemaker-remote"] || []

    if elements.key?("hawk-server")
      elements["hawk-server"].each do |n|
        @logger.debug("checking #{n}")
        next if members.include? n

        node = NodeObject.find_node_by_name(n)
        name = node.name
        name = "#{node.alias} (#{name})" if node.alias
        validation_error I18n.t(
          "barclamp.#{bc_name}.validation.hawk_server",
          name: name
        )
      end
    end

    if proposal["attributes"][@bc_name]["notifications"]["smtp"]["enabled"]
      smtp_settings = proposal["attributes"][@bc_name]["notifications"]["smtp"]
      validation_error I18n.t(
        "barclamp.#{bc_name}.validation.smtp_server"
      ) if smtp_settings["server"].blank?
      validation_error I18n.t(
        "barclamp.#{bc_name}.validation.sender_address"
      ) if smtp_settings["from"].blank?
      validation_error I18n.t(
        "barclamp.#{bc_name}.validation.recipient_address"
      ) if smtp_settings["to"].blank?
    end

    if proposal["attributes"][@bc_name]["drbd"]["enabled"]
      validation_error I18n.t(
        "barclamp.#{bc_name}.validation.drbd"
      ) if members.length != 2
    end

    nodes = NodeObject.find("roles:provisioner-server")
    unless nodes.nil? or nodes.length < 1
      provisioner_server_node = nodes[0]
      if provisioner_server_node[:platform] == "suse"
        unless Crowbar::Repository.provided_and_enabled? "ha"
          validation_error I18n.t(
            "barclamp.#{bc_name}.validation.hae_repo"
          )
        end
      end
    end

    transport = proposal["attributes"][@bc_name]["corosync"]["transport"]
    unless %w(udp udpu).include?(transport)
      validation_error I18n.t(
        "barclamp.#{bc_name}.validation.transport_value",
        transport: transport
      )
    end

    no_quorum_policy = proposal["attributes"][@bc_name]["crm"]["no_quorum_policy"]
    unless %w(ignore freeze stop suicide).include?(no_quorum_policy)
      validation_error I18n.t(
        "barclamp.#{bc_name}.validation.quorum_policy",
        no_quorum_policy: no_quorum_policy
      )
    end

    stonith_attributes = proposal["attributes"][@bc_name]["stonith"]
    validate_proposal_stonith stonith_attributes, members + remotes

    # Let's not pretend we'll get clusters with nodes on different distros work
    target_platforms = members.map do |member|
      node = NodeObject.find_node_by_name member
      if node.nil?
        nil
      else
        node.target_platform
      end
    end
    unless target_platforms.uniq.length <= 1
      validation_error validation_error I18n.t(
        "barclamp.#{bc_name}.validation.platform"
      )
    end

    ### Do not allow elements of this proposal to be in another proposal, since
    ### the configuration cannot be shared.
    proposals_raw.each do |p|
      next if p["id"] == proposal["id"]

      other_members = p["deployment"][@bc_name]["elements"]["pacemaker-cluster-member"] || []
      other_remotes = p["deployment"][@bc_name]["elements"]["pacemaker-remote"] || []
      (other_members + other_remotes).each do |other_member|
        next unless members.include?(other_member) || remotes.include?(other_member)

        p_name = p["id"].gsub("#{@bc_name}-", "")
        validation_error I18n.t(
          "barclamp.#{bc_name}.validation.pacemaker_proposal",
          other_member: other_member,
          p_name: p_name
        )
      end
    end

    super
  end
end

