#
# Cookbook Name:: corosync
# Recipe:: client
#
# Copyright 2012, Rackspace US, Inc.
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

# chef makes csync2 redundant
if node[:platform_family] == "suse"
  service "csync2" do
    action [:stop, :disable]
  end
end

if node[:platform_family] == "rhel"
  # http://clusterlabs.org/quickstart.html
  Chef::Application.fatal! "FIXME: RedHat-based platforms configure corosync via cluster.conf"
  return
end

unless %(udp udpu).include?(node[:corosync][:transport])
  raise "Invalid transport #{node[:corosync][:transport]}!"
end

rings = node[:corosync][:rings]

member_count = nil
rings.each.with_index do |ring, ring_index|
  # check for empty
  if ring[:members].nil? || ring[:members].empty?
    raise "One or more members are required. The member list of "\
      "ring #{ring_index} is empty."
  end

  # check for matching member count across rings
  if member_count.nil?
    member_count = ring[:members].length
  elsif ring[:members].length != member_count
    raise "All rings must have the same number of members. Ring #{ring_index} "\
      "has #{ring[:members].length} members but all preceding rings have #{member_count}."
  end
end

# gather member addresses together by node for corosync.conf.v2.erb by
# building and transposing a two dimensional member array that is sorted
# by ring 0 members to avoid unnecessary configuration reloads
members_v2 = []
sort_by_ring0 = node[:corosync][:rings][0][:members]
node[:corosync][:rings].each do |ring|
  members_v2.push(ring[:members].sort_by.with_index { |_, i| sort_by_ring0[i] })
end
members_v2 = members_v2.transpose

template "/etc/corosync/corosync.conf" do
  if node[:platform] == "suse" && node[:platform_version].to_f < 12.0
    source "corosync.conf.erb"
  else
    source "corosync.conf.v2.erb"
  end
  owner "root"
  group "root"
  mode 0600
  variables(
    cluster_name: node[:corosync][:cluster_name],
    rings: node[:corosync][:rings],
    members_v2: members_v2,
    transport: node[:corosync][:transport]
  )

  # If the config parameters are changed, it's too risky to just
  # restart the cluster - this could happen on all cluster nodes at a
  # similar time and cause a significant outage.  Fortunately it's
  # possible to instead reload the config whilst keeping corosync running,
  # via corosync-cfgtool -R.
end

corosync_action = :delayed

if node[:crowbar_wall][:cluster_members_changed]
  corosync_action = :immediately
  node.set[:crowbar_wall][:cluster_members_changed] = false
  node.save
end

execute "reload corosync.conf" do
  # corosync-cfgtool -R reloads the configuration across ALL the nodes in the
  # cluster - each reloading its own local configuration file. This means that
  # running this command on a cluster with n nodes results in n^2 reloads.
  # Given that the reloads might happen while some of the nodes still having
  # the old configuration, this approach is not valid for updating nodelist
  # or votequorum parameters, but should work for amending token timeouts.
  # Ideally we would synchronize between all nodes after the config files are
  # updated, and then just run the reload on a single node, but we can only
  # achieve that when the proposal is being applied, and we need something
  # which works with the convergence runs.
  command "corosync-cfgtool -R"
  user "root"
  group "root"
  action :nothing
  subscribes :run, "template[/etc/corosync/corosync.conf]", corosync_action
end
