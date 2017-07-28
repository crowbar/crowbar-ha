#
# Cookbook Name:: crowbar-pacemaker
# Recipe:: mutual_ssh
#
# Copyright 2015, SUSE
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

# Allow mutual ssh connection among cluster members: go through the
# cluster nodes and remember the public keys so the provisioner can
# save them.  This is required so that hb_report can gather logs from
# all cluster members.

cluster_access_keys = []

CrowbarPacemakerHelper.cluster_nodes(node).each do |cluster_node|
  pkey = nil
  if cluster_node[:crowbar][:ssh]
    pkey = cluster_node[:crowbar][:ssh][:root_pub_key]
  end
  if !pkey.nil? && cluster_node.name != node.name && !cluster_access_keys.include?(pkey)
    cluster_access_keys.push(pkey)
  end
end

return if cluster_access_keys.empty?

access_keys = [
  node.default["provisioner"]["access_keys"].strip,
  cluster_access_keys
].flatten.join("\n")

if node["provisioner"]["access_keys"] != access_keys
  node.set["provisioner"]["access_keys"] = access_keys
  node.save
end
