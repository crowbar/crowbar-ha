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
# cluster nodes and remember the public keys so the provisioner can save them.

access_keys = {}

node["provisioner"]["access_keys"].strip.split("\n").each do |key|
  key.strip!
  if !key.empty?
    nodename = key.split(" ")[2]
    access_keys[nodename] = key
  end
end

CrowbarPacemakerHelper.cluster_nodes(node).each do |cluster_node|
  pkey = cluster_node[:crowbar][:ssh][:root_pub_key] rescue nil
  if !pkey.nil? && cluster_node.name != node.name && !access_keys.values.include?(pkey)
    access_keys[cluster_node.name] = pkey
  end
end

if access_keys.size > 0
  node["provisioner"]["access_keys"] = access_keys.values.join("\n")
  node.save
end
