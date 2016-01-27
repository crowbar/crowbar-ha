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

#
# This is a subclass of ServiceObject providing some helpers methods.
# Barclamps that have roles using pacemaker clusters should subclass this.
#
# It also provides some helpers that ServiceObject will wrap.
#

class PacemakerServiceObject < ServiceObject
  #
  # Eigenclass with methods used by ServiceObject
  #

  class << self
    # Note that we cannot cache the list of clusters here as we're in a
    # eigenclass, and so the cache will be longer term than a single request
    # (hence we won't notice new clusters). It's therefore up to the callers to
    # cache this.
    # Returns: list of available clusters
    def available_clusters
      clusters = {}
      # we only care about the deployed clusters, not about existing
      # proposals
      RoleObject.find_roles_by_name("pacemaker-config-*").each do |role|
        clusters["#{cluster_key}:#{role.inst}"] = role
      end
      clusters
    end

    # Returns: List of available clusters including remotes
    def available_remotes
      remotes = {}
      # we only care about the deployed clusters, not about existing
      # proposals
      RoleObject.find_roles_by_name("pacemaker-config-*").select do |role|
        elements = role.override_attributes["pacemaker"]["elements"]
        elements["pacemaker-remote"] && !elements["pacemaker-remote"].empty?
      end.each do |role|
        remotes["#{remotes_key}:#{role.inst}"] = role
      end
      remotes
    end

    # This is the key that allows to find out that an element item is a
    # pacemaker cluster excluding remote nodes: if the element name is
    # $cluster_key:$foo, then it's one. Otherwise, it's not.
    def cluster_key
      "cluster"
    end

    def is_cluster?(element)
      element.start_with? "#{cluster_key}:"
    end

    def cluster_vhostname_from_name(name)
      # We know that the proposal name cannot contain a dash, and we know that
      # a hostname cannot contain an underscore, so we're lucky and we can
      # substitute one with the other.
      # Similar code is in the cookbook:
      # CrowbarPacemakerHelper.cluster_vhostname
      "cluster-#{name.gsub("_", "-")}.#{ChefObject.cloud_domain}"
    end

    # This is the key that allows to find out that an element item is a
    # pacemaker cluster including remote nodes: if the element name is
    # $remotes_key:$foo, then it's one. Otherwise, it's not.
    def remotes_key
      "remotes"
    end

    def is_remotes?(element)
      element.start_with? "#{remotes_key}:"
    end

    def remotes_remote_nodes_count(element)
      if is_remotes?(element)
        role = RoleObject.find_role_by_name("pacemaker-config-#{cluster_name(element)}")
        elements = role.override_attributes["pacemaker"]["elements"]
        elements["pacemaker-remote"].nil? ? 0 : elements["pacemaker-remote"].length
      else
        0
      end
    end

    # Returns: name of the barclamp and of the proposal for this cluster
    def cluster_get_barclamp_and_proposal(element)
      if is_cluster?(element) || is_remotes?(element)
        ["pacemaker", cluster_name(element)]
      else
        [nil, nil]
      end
    end

    # Returns: name of the cluster, or nil if it's not a cluster
    def cluster_name(element)
      case
      when is_remotes?(element)
        element.gsub("#{remotes_key}:", "")
      when is_cluster?(element)
        element.gsub("#{cluster_key}:", "")
      else
        nil
      end
    end

    def cluster_vhostname_from_element(element)
      if is_cluster?(element)
        cluster_vhostname_from_name(cluster_name(element))
      else
        nil
      end
    end

    # Get the founder of a cluster, based on the element
    def cluster_founder(element)
      if is_cluster?(element)
        cluster = cluster_name(element)
        NodeObject.find("pacemaker_founder:true AND pacemaker_config_environment:pacemaker-config-#{cluster}").first
      else
        nil
      end
    end

    # Returns: list of nodes in the cluster, or nil if the cluster doesn't exist
    def expand_nodes(cluster)
      clusters = available_clusters
      if clusters[cluster].nil?
        nil
      else
        pacemaker_proposal = clusters[cluster]
        cluster_nodes = pacemaker_proposal.override_attributes["pacemaker"]["elements"]["pacemaker-cluster-member"]
        cluster_nodes || []
      end
    end

    # Returns: list of remote nodes in the cluster, or nil if the cluster doesn't exist
    def expand_remote_nodes(cluster)
      remotes = available_remotes
      if remotes[cluster].nil?
        nil
      else
        pacemaker_proposal = remotes[cluster]
        remote_nodes = pacemaker_proposal.override_attributes["pacemaker"]["elements"]["pacemaker-remote"]
        remote_nodes || []
      end
    end
  end

  def expand_remote_nodes(cluster)
    PacemakerServiceObject.expand_remote_nodes(cluster)
  end

  #
  # Helpers to use in apply_role_pre_chef_call
  #

  # This returns a list that contains:
  #   - elements assigned to the role
  #   - nodes assigned to the roles; this can be different from elements if an
  #     element was a cluster (in which case, the cluster will have been
  #     expanded to a list of nodes)
  #   - whether elements != nodes (which typically means that HA will be
  #     enabled; but it could be used for other things)
  def role_expand_elements(role, role_name)
    elements = role.override_attributes[@bc_name]["elements"][role_name]
    expanded_nodes = nil
    if role.override_attributes[@bc_name].key?("elements_expanded")
      expanded_nodes = role.override_attributes[@bc_name]["elements_expanded"][role_name]
    end
    elements ||= []
    expanded_nodes ||= []

    if elements.empty? || expanded_nodes.empty?
      has_expanded = false
      all_nodes = elements
    else
      has_expanded = (expanded_nodes.sort != elements.sort)
      all_nodes = expanded_nodes
    end

    [elements, all_nodes, has_expanded]
  end

  # !!! Horrible workaround until we fix crowbar orchestration !!!
  # Because each chef-client runs executes everything in all cookbooks, and
  # because the crm calls slow things down considerably, we have a drift issue
  # where the founder (which does much more work since it's the only one doing
  # the crm calls) goes much slower than the other nodes. This can impact
  # things badly when it's so slow that it triggers the timeout in the sync
  # marks.
  # The workaround here is to reset the sync marks on the founder, so that all
  # nodes wait on the sync marks and the drift is only happening between sync
  # marks.
  # The goal is to only do this when applying a proposal, so that other
  # chef-client runs are not blocked waiting for sync marks.
  def self.reset_sync_marks_on_cluster_founder(founder, cluster)
    return if founder.nil? ||
        founder[:pacemaker].nil? ||
        founder[:pacemaker][:sync_marks].nil? ||
        founder[:pacemaker][:sync_marks][cluster].nil?

    founder[:pacemaker][:sync_marks][cluster].keys.each do |sync_mark|
      # The pacemaker_setup sync mark (see the crowbar-pacemaker::default
      # recipe) requires special handling: it is created by the founder in
      # Chef's convergence phase, but waited for by all non-founders in Chef's
      # compile phase, because they need it in order to copy the authkey
      # attribute from the founder to themselves and then invoke the
      # corosync::authkey_writer recipe.
      #
      # This is only required for initial pacemaker setup and running in
      # compile phase, so we don't want to reset it.  If we were to reset it,
      # then every time a proposal was applied, the non-founder nodes would be
      # blocked in their compile phase until the founder reached the point in
      # its convergence phase where it creates the pacemaker_setup sync mark,
      # and this would be too long for the non-founders to wait when the run
      # list is long.
      next if sync_mark == "pacemaker_setup"
      founder[:pacemaker][:sync_marks][cluster].delete(sync_mark)
    end

    founder.save
  end

  def reset_sync_marks_on_clusters_founders(elements)
    elements.each do |element|
      next unless PacemakerServiceObject.is_cluster? element

      founder = PacemakerServiceObject.cluster_founder(element)
      cluster = cluster_name(element)

      PacemakerServiceObject.reset_sync_marks_on_cluster_founder(founder, cluster)
    end
  end

  # This allocates a virtual IP for the cluster in each network in networks
  # (which is a list)
  # Returns: two booleans:
  #   - first one tells whether the call succeeded
  #   - second one tells whether virtual IPs were newly allocated (as opposed
  #     to the fact that they were already existing, so no action had to be
  #     taken). This information can be used to know when a DNS sync is
  #     required or not.
  def allocate_virtual_ips_for_cluster_in_networks(cluster, networks)
    if networks.nil? || networks.empty? || !PacemakerServiceObject.is_cluster?(cluster)
      [false, false]
    else
      nodes = PacemakerServiceObject.expand_nodes(cluster)
      if nodes.empty?
        [false, false]
      else
        cluster_vhostname = PacemakerServiceObject.cluster_vhostname_from_element(cluster)

        net_svc = NetworkService.new @logger
        new_allocation = false

        networks.each do |network|
          next if net_svc.virtual_ip_assigned? "default", network, "host", cluster_vhostname
          net_svc.allocate_virtual_ip "default", network, "host", cluster_vhostname
          new_allocation = true
        end

        [true, new_allocation]
      end
    end
  end

  # This is wrapper method for allocate_virtual_ips_for_cluster_in_networks. It
  # will call it for any element of elements that is a cluster.
  # Returns: whether there was a new allocation
  def allocate_virtual_ips_for_any_cluster_in_networks(elements, networks)
    new_allocation = false

    elements.each do |element|
      if PacemakerServiceObject.is_cluster?(element)
        ok, new = allocate_virtual_ips_for_cluster_in_networks(element, networks)
        new_allocation ||= new
      end
    end

    new_allocation
  end

  # This is wrapper method for allocate_virtual_ips_for_any_cluster_in_networks.
  # It will ensure dns is up-to-date if needed.
  def allocate_virtual_ips_for_any_cluster_in_networks_and_sync_dns(elements, networks)
    do_dns = allocate_virtual_ips_for_any_cluster_in_networks(elements, networks)
    ensure_dns_uptodate if do_dns
  end

  def ensure_dns_uptodate
    # We need to make sure DNS is updated in some cases (if a recipe has code
    # to contact the virtual name, for instance)
    # FIXME: right now, this is non-blocking so there could be a race where the
    # cookbook code is executed faster. So far, it seems it's not an issue
    # (we're not even hitting the "will run chef-client a second time if first
    # one fails), but this would still need to be improved.
    system("sudo", "-i", Rails.root.join("..", "bin", "single_chef_client.sh").expand_path.to_s)
  end

  # This prepares attributes so that, if ha_enabled is true, the chef run will
  # configure haproxy on a virtual IP for each network in networks for the
  # clusters in elements.
  # The role parameter is the proposal role (as passed to
  # apply_role_pre_chef_call).
  # Returns: whether the role needs to be saved or not
  def prepare_role_for_cluster_vip_networks(role, elements, networks)
    dirty = false

    elements.each do |element|
      next unless PacemakerServiceObject.is_cluster?(element)

      cluster = cluster_name(element)

      role.default_attributes["pacemaker"] ||= {}
      role.default_attributes["pacemaker"]["haproxy"] ||= {}
      role.default_attributes["pacemaker"]["haproxy"]["clusters"] ||= {}
      role.default_attributes["pacemaker"]["haproxy"]["clusters"][cluster] ||= {}
      role.default_attributes["pacemaker"]["haproxy"]["clusters"][cluster]["networks"] ||= {}

      networks.each do |network|
        unless role.default_attributes["pacemaker"]["haproxy"]["clusters"][cluster]["networks"][network]
          role.default_attributes["pacemaker"]["haproxy"]["clusters"][cluster]["networks"][network] = true
          dirty = true
        end
      end

      unless role.default_attributes["pacemaker"]["haproxy"]["clusters"][cluster]["enabled"]
        role.default_attributes["pacemaker"]["haproxy"]["clusters"][cluster]["enabled"] = true
        dirty = true
      end
    end

    dirty
  end

  # This prepares attributes for HA.
  #
  # attribute_path is the path (in terms of attributes) to set to true/false
  # depending on ha_enabled. For instance: with ["keystone", "ha", "enabled"],
  # the method will set role.default_attributes["keystone"]["ha"]["enabled"]
  #
  # Returns: whether the role needs to be saved or not
  def prepare_role_for_ha(role, attribute_path, ha_enabled)
    dirty = false

    data = role.default_attributes
    attribute_path[0, attribute_path.length - 1].each { |attribute|
      if not (data.key?(attribute) && data[attribute].is_a?(Hash))
        data[attribute] = {}
      end
      data = data[attribute]
    }

    if data[attribute_path[-1]] != ha_enabled
      data[attribute_path[-1]] = ha_enabled
      dirty = true
    end

    dirty
  end

  # This prepares attributes for HA, with haproxy. It will call
  # prepare_role_for_ha and, if HA is wanted,
  # prepare_role_for_cluster_vip_networks.
  #
  # See prepare_role_for_ha documentation for description of how attribute_path
  # works.
  #
  # Returns: whether the role needs to be saved or not
  def prepare_role_for_ha_with_haproxy(role, attribute_path, ha_enabled, elements, networks)
    dirty = prepare_role_for_ha(role, attribute_path, ha_enabled)

    if ha_enabled
      dirty = prepare_role_for_cluster_vip_networks(role, elements, networks) || dirty
    end

    dirty
  end
end
