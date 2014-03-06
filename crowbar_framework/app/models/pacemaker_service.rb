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

  #if barclamp allows multiple proposals OVERRIDE
  # def self.allow_multiple_proposals?
  #   true
  # end

  def create_proposal
    @logger.debug("Pacemaker create_proposal: entering")
    base = super

    @logger.debug("Pacemaker create_proposal: exiting")
    base
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Pacemaker apply_role_pre_chef_call: entering #{all_nodes.inspect}")

    admin_net = ProposalObject.find_data_bag_item "crowbar/admin_network"

    role.default_attributes["corosync"] ||= {}
    role.default_attributes["corosync"]["bind_addr"] = admin_net["network"]["subnet"]

    unless role.default_attributes["pacemaker"]["corosync"]["password"].empty?
      old_role_password = old_role.default_attributes["pacemaker"]["corosync"]["password"]
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

  def validate_proposal_after_save proposal
    validate_one_for_role proposal, "pacemaker-cluster-founder"

    elements = proposal["deployment"]["pacemaker"]["elements"]

    if elements.has_key?("hawk-server")
      @logger.debug("Pacemaker apply_role_pre_chef_call: elts #{elements.inspect}")
      members = (elements["pacemaker-cluster-founder"] || []) +
                (elements["pacemaker-cluster-member" ] || [])
      @logger.debug("cluster members: #{members}")

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

    super
  end

end

