# Functions to help recipes register resources in the Pacemaker cluster
# via the LWRPs provided by the pacemaker cookbook.
#
# Even though the haproxy frontend only runs on one node at a time, we
# need to ensure that all nodes have haproxy.cfg correctly configured
# ahead of time, in case the frontend needs to be failed over.
module CrowbarPacemakerHelper
  def self.cluster_enabled?(node)
    return !(node[:pacemaker][:config][:environment] rescue nil).nil?
  end

  # Returns the name of the cluster containing the given node, or nil
  # if the node is not in a cluster.  The name is determined by the
  # name of the pacemaker proposal corresponding to that cluster
  # (minus the "pacemaker-config-" prefix which is visible at the Chef
  # level).
  #
  # This call signature only makes sense because it is not possible
  # for a node to be in multiple clusters.
  def self.cluster_name(node)
    if cluster_enabled?(node)
      node[:pacemaker][:config][:environment].gsub("pacemaker-config-", "")
    else
      nil
    end
  end

  # Floating virtual IPs are used for the haproxy frontend endpoints,
  # and these have corresponding virtual hostnames.  This helper
  # constructs the non-qualified host prefix part of the virtual
  # hostname.
  def self.cluster_vhostname(node)
    if cluster_enabled?(node)
      "cluster-#{cluster_name(node)}"
    else
      nil
    end
  end

  # Performs a Chef search and returns an Array of Node objects for
  # all nodes in the same cluster as the given node, or an empty array
  # if the node isn't in a cluster.  Can optionally filter by role.
  #
  # This call signature only makes sense because it is not possible
  # for a node to be in multiple clusters.
  def self.cluster_nodes(node, role = "*")
    if cluster_enabled?(node)
      server_nodes = []
      Chef::Search::Query.new.search(:node, "roles:#{role || "*"} AND pacemaker_config_environment:#{node[:pacemaker][:config][:environment]}") { |o| server_nodes << o }
      server_nodes
    else
      []
    end
  end

  # Returns an Array with two elements:
  #
  # 1. An Array of Hashes representing haproxy backend servers,
  #    where each Hash looks something like:
  #
  #      {
  #        'name' => 'd52-54-00-b5-4c-c6.crowbar.site',
  #        'address' => '192.168.124.81',
  #        'port' => 0,
  #      }
  #
  #    This Array will eventually be passed to the
  #    haproxy_loadbalancer LWRP as the servers parameter.
  #
  # 2. A Hash mapping the hostnames of the haproxy backend servers
  #    to their Chef Node objects.  This will be used to obtain
  #    additional data from the Node.
  def self.haproxy_servers(node, role = "*")
    haproxy_servers = []
    haproxy_servers_nodes = {}

    server_nodes = cluster_nodes(node, role)

    server_nodes.each do |server_node|
      haproxy_server = {}
      haproxy_server['name'] = server_node[:hostname]
      haproxy_server['address'] = server_node[:ipaddress]
      haproxy_server['port'] = 0
      haproxy_servers << haproxy_server
      haproxy_servers_nodes[server_node[:hostname]] = server_node
    end

    [haproxy_servers, haproxy_servers_nodes]
  end
end
