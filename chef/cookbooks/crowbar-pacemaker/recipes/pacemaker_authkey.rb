#
# Cookbook Name:: crowbar-pacemaker
# Recipe:: pacemaker_authkey
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

# This recipe is intended for use on *all* cluster nodes, i.e. both
# corosync and remote nodes.  Only the founder generates an authkey
# for communication with remote nodes, and all the others copy it;
# thefore it must be run on the corosync nodes first.  Crowbar
# achieves this by first running it via the pacemaker-cluster-member
# role, and then later by the pacemaker-remote role.

if CrowbarPacemakerHelper.is_cluster_founder?(node)
  if node[:pacemaker][:authkey].nil?
    include_recipe "pacemaker::authkey_generator"
  else
    # make sure the authkey stays written
    include_recipe "pacemaker::authkey_writer"
  end
else
  authkey_node = CrowbarPacemakerHelper.cluster_founder(node)

  log("Using pacemaker authkey from node: #{authkey_node.name}")
  authkey = authkey_node[:pacemaker][:authkey]

  node.set[:pacemaker][:authkey] = authkey
  node.save
  include_recipe "pacemaker::authkey_writer"
end
