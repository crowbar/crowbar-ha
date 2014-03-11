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


# Translate IPMI stonith mode from the barclamp into something that can be
# understood from the pacemaker cookbook
if node[:pacemaker][:stonith][:mode] == "ipmi_barclamp"
  node.default[:pacemaker][:stonith][:mode] = "per_node"
  node.default[:pacemaker][:stonith][:per_node][:plugin] = "external/ipmi"
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
end
