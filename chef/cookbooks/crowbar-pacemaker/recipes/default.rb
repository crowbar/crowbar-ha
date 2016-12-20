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
node.normal[:corosync][:cluster_name] = CrowbarPacemakerHelper.cluster_name(node)
node.normal[:corosync][:bind_addr] = Barclamp::Inventory.get_network_by_type(node, "admin").address

include_recipe "crowbar-pacemaker::quorum_policy"
include_recipe "crowbar-pacemaker::stonith"

# We let the founder go first, so it can generate the authkey and some other
# initial pacemaker configuration bits; we do it in the compile phase of the
# chef run because the non-founder nodes will look during the compile phase for
# the attribute, while the attribute is set during the convergence phase of the
# founder node.
# Note that resetting this sync mark should be avoided after the initial setup
# is done: since wait is done during compile phase and create is done during
# convergence phase, it can create a drift between the founder node and the
# non-founder nodes.
crowbar_pacemaker_sync_mark "wait-pacemaker_setup" do
  revision node[:pacemaker]["crowbar-revision"]
  # we use a longer timeout because the wait / create are in two different
  # phases, and this wait is fatal in case of errors
  timeout 120
  fatal true
end.run_action(:guess)

include_recipe "pacemaker::default"

# Set up authkey for pacemaker remotes (different to corosync authkey)
include_recipe "crowbar-pacemaker::pacemaker_authkey"

# This part of the synchronization is *not* done in the compile phase, because
# saving the corosync authkey attribute is done in convergence phase for
# founder (but reading the attribute is done in compile phase for non-founder
# nodes) -- see the corosync::authkey_generator recipe.
crowbar_pacemaker_sync_mark "create-pacemaker_setup" do
  revision node[:pacemaker]["crowbar-revision"]
end

include_recipe "crowbar-pacemaker::attributes"
include_recipe "crowbar-pacemaker::maintenance-mode"
include_recipe "crowbar-pacemaker::mutual_ssh"

include_recipe "crowbar-pacemaker::openstack"

if node[:pacemaker][:drbd][:enabled]
  include_recipe "crowbar-pacemaker::drbd_setup"
end
