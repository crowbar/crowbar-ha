#
# Cookbook Name:: crowbar-pacemaker
# Recipe:: default
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

require "timeout"

node.normal[:corosync][:cluster_name] = CrowbarPacemakerHelper.cluster_name(node)

# set bindnetaddr per node, use host address rather than network subnet
# in case multiple interfaces are configured on the same subnet
node[:corosync][:rings].each_with_index do |ring, index|
  ring[:bind_addr] = Barclamp::Inventory.get_network_by_type(node, ring[:network]).address
end

include_recipe "crowbar-pacemaker::quorum_policy"
include_recipe "crowbar-pacemaker::stonith"

# We let the founder go first, so it can generate the authkey and some other
# initial pacemaker configuration bits; we do it in the compile phase of the
# chef run because the non-founder nodes will look during the compile phase for
# the attribute, while the attribute is set during the convergence phase of the
# founder node.
unless CrowbarPacemakerHelper.is_cluster_founder?(node)
  begin
    # we use a long timeout because the wait / attribute-set are in two different
    # phases, and this wait is fatal in case of errors
    Timeout.timeout(120) do
      Chef::Log.info("Waiting for cluster founder to be set up...")
      loop do
        founder = CrowbarPacemakerHelper.cluster_founder(node)
        # be safe, in case the node doesn't have pacemaker attributes yet
        # (depends on whether chef already started on it or not)
        if founder.fetch("pacemaker", {})[:setup]
          if founder[:pacemaker][:reset_sync_marks]
            Chef::Log.info("Cluster founder is resetting sync marks, waiting...")
          else
            Chef::Log.info("Cluster founder is set up, going on...")
            break
          end
        else
          Chef::Log.info("Cluster founder not set up yet, waiting...")
        end
        sleep(5)
      end # while true
    end # Timeout
  rescue Timeout::Error
    raise "Cluster founder not set up!"
  end
end

dirty = false

# remove old-style sync marks (from <= 3.0 days)
if node.normal_attrs[:pacemaker][:sync_marks]
  # if founder, actually migrate all sync marks
  if CrowbarPacemakerHelper.is_cluster_founder?(node)
    CrowbarPacemakerHelper.cluster_nodes(node).each do |cluster_node|
      CrowbarPacemakerSynchronization.migrate_sync_marks_v1(cluster_node)
    end
  end
  node.normal_attrs[:pacemaker].delete(:sync_marks)
  dirty = true
end

if CrowbarPacemakerHelper.is_cluster_founder?(node) && node[:pacemaker][:reset_sync_marks]
  # we can't reset sync marks if the pacemaker stack is not set up...
  if node[:pacemaker][:setup]
    CrowbarPacemakerHelper.cluster_nodes(node).each do |cluster_node|
      CrowbarPacemakerSynchronization.reset_marks(cluster_node)
    end
  end
  # ... but we don't want to block the other nodes forever
  node.set[:pacemaker][:reset_sync_marks] = false
  dirty = true
end

node.save if dirty

# make sure all ssh keys are deployed before joining the cluster to allow
# alert handlers to ssh to this node if needed.
# Also include each member of the cluster so they can communitcate or rsync if necessary.
include_recipe "crowbar-pacemaker::mutual_ssh"
include_recipe "provisioner::keys"

include_recipe "pacemaker::default"

# Set up authkey for pacemaker remotes (different to corosync authkey)
include_recipe "crowbar-pacemaker::pacemaker_authkey"

# This part of the synchronization is *not* done in the compile phase, because
# saving the corosync authkey attribute is done in convergence phase for
# founder (but reading the attribute is done in compile phase for non-founder
# nodes) -- see the corosync::authkey_generator recipe.
ruby_block "mark node as ready for pacemaker" do
  block do
    dirty = false
    unless node[:pacemaker][:setup]
      node.set[:pacemaker][:setup] = true
      dirty = true
    end
    if node[:crowbar_wall][:cluster_node_added]
      node.set[:crowbar_wall][:cluster_node_added] = false
      dirty = true
    end
    node.save if dirty
  end
end

include_recipe "crowbar-pacemaker::attributes"
include_recipe "crowbar-pacemaker::maintenance-mode"

include_recipe "crowbar-pacemaker::openstack"

if node[:pacemaker][:drbd][:enabled]
  include_recipe "crowbar-pacemaker::drbd_setup"
end
